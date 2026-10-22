USE movie_db;
--procedures and triggers
	CREATE TABLE IF NOT EXISTS movie_rating_cache (
		movie_id INT PRIMARY KEY,
		review_count INT NOT NULL DEFAULT 0,
		average_rating DECIMAL(3,2) NULL,
		last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		CONSTRAINT fk_cache_movie FOREIGN KEY (movie_id)
			REFERENCES movies(movie_id) ON DELETE CASCADE
	) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movie_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    movie_id INT, title VARCHAR(200), release_year SMALLINT UNSIGNED,
    deleted_by VARCHAR(100), deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

REPLACE INTO movie_rating_cache (movie_id, review_count, average_rating)
SELECT m.movie_id, COUNT(r.review_id), ROUND(AVG(r.rating), 2)
FROM movies m LEFT JOIN reviews r ON r.movie_id = m.movie_id
GROUP BY m.movie_id;

DROP FUNCTION IF EXISTS get_avg_rating;
DROP FUNCTION IF EXISTS rating_label;
DROP PROCEDURE IF EXISTS search_movies;
DROP PROCEDURE IF EXISTS get_movies_by_director;
DROP PROCEDURE IF EXISTS get_person_filmography;
DROP PROCEDURE IF EXISTS add_review;
DROP PROCEDURE IF EXISTS add_movie_tx;

DELIMITER //

CREATE FUNCTION get_avg_rating(p_movie_id INT) RETURNS DECIMAL(3,2)
READS SQL DATA
BEGIN
    DECLARE v_avg DECIMAL(3,2);
    SELECT ROUND(AVG(rating), 2) INTO v_avg FROM reviews WHERE movie_id = p_movie_id;
    RETURN v_avg;
END //

CREATE FUNCTION rating_label(p_avg DECIMAL(3,2)) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    IF p_avg IS NULL THEN RETURN 'Not rated'; END IF;
    IF p_avg >= 4.5 THEN RETURN 'Masterpiece'; END IF;
    IF p_avg >= 4.0 THEN RETURN 'Highly rated'; END IF;
    IF p_avg >= 3.0 THEN RETURN 'Good'; END IF;
    RETURN 'Mixed';
END //

-- NULL argument = ignore that filter
CREATE PROCEDURE search_movies(
    IN p_country VARCHAR(100), IN p_year INT, IN p_genre VARCHAR(60),
    IN p_min_rating DECIMAL(3,2), IN p_language VARCHAR(60))
BEGIN
    SELECT m.movie_id, m.title, m.release_year, m.country, m.original_language,
           (SELECT GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ')
              FROM movie_genres mg JOIN genres g ON g.genre_id = mg.genre_id
             WHERE mg.movie_id = m.movie_id) AS genres,
           s.average_rating
    FROM movies m
    LEFT JOIN movie_review_summary s ON s.movie_id = m.movie_id
    WHERE (p_country  IS NULL OR m.country = p_country)
      AND (p_year     IS NULL OR m.release_year = p_year)
      AND (p_language IS NULL OR m.original_language = p_language)
      AND (p_min_rating IS NULL OR s.average_rating >= p_min_rating)
      AND (p_genre IS NULL OR EXISTS (
            SELECT 1 FROM movie_genres mg JOIN genres g ON g.genre_id = mg.genre_id
             WHERE mg.movie_id = m.movie_id AND g.genre_name = p_genre))
    ORDER BY s.average_rating DESC, m.title;
END //

CREATE PROCEDURE get_movies_by_director(IN p_name VARCHAR(160))
BEGIN
    SELECT m.title, m.release_year, m.country,
           (SELECT GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ')
              FROM movie_genres mg JOIN genres g ON g.genre_id = mg.genre_id
             WHERE mg.movie_id = m.movie_id) AS genres,
           (SELECT GROUP_CONCAT(p2.full_name ORDER BY p2.full_name SEPARATOR ', ')
              FROM movie_credits c2 JOIN people p2 ON p2.person_id = c2.person_id
             WHERE c2.movie_id = m.movie_id AND c2.role_name = 'Actor') AS actors,
           get_avg_rating(m.movie_id) AS avg_rating
    FROM movies m
    JOIN movie_credits c ON c.movie_id = m.movie_id AND c.role_name = 'Director'
    JOIN people p ON p.person_id = c.person_id
    WHERE p.full_name LIKE CONCAT('%', p_name, '%')
    ORDER BY m.release_year;
END //

CREATE PROCEDURE get_person_filmography(IN p_name VARCHAR(160))
BEGIN
    SELECT p.full_name, c.role_name, m.title, m.release_year,
           rating_label(get_avg_rating(m.movie_id)) AS rating_label
    FROM people p
    JOIN movie_credits c ON c.person_id = p.person_id
    JOIN movies m ON m.movie_id = c.movie_id
    WHERE p.full_name LIKE CONCAT('%', p_name, '%')
    ORDER BY m.release_year, c.role_name;
END //

CREATE PROCEDURE add_review(
    IN p_movie INT, IN p_reviewer INT, IN p_rating DECIMAL(2,1), IN p_text VARCHAR(1000))
BEGIN
    INSERT INTO reviews (movie_id, reviewer_id, rating, review_text, review_date)
    VALUES (p_movie, p_reviewer, p_rating, p_text, CURDATE());
    SELECT m.title, c.review_count, c.average_rating,
           rating_label(c.average_rating) AS label
    FROM movies m JOIN movie_rating_cache c ON c.movie_id = m.movie_id
    WHERE m.movie_id = p_movie;
END //
	
-- All-or-nothing: movie + genre + director + actor
CREATE PROCEDURE add_movie_tx(
    IN p_title VARCHAR(200), IN p_year SMALLINT, IN p_country VARCHAR(100),
    IN p_language VARCHAR(60), IN p_runtime SMALLINT, IN p_genre VARCHAR(60),
    IN p_director_id INT, IN p_actor_id INT)
BEGIN
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'FAILED - transaction rolled back' AS status;
    END;

    START TRANSACTION;
    INSERT INTO movies (title, release_year, country, original_language, runtime_minutes)
    VALUES (p_title, p_year, p_country, p_language, p_runtime);
    SET v_id = LAST_INSERT_ID();

    INSERT INTO movie_genres (movie_id, genre_id)
    SELECT v_id, genre_id FROM genres WHERE genre_name = p_genre;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown genre';
    END IF;

    INSERT INTO movie_credits (movie_id, person_id, role_name) VALUES (v_id, p_director_id, 'Director');
    INSERT INTO movie_credits (movie_id, person_id, role_name) VALUES (v_id, p_actor_id, 'Actor');
    COMMIT;
    SELECT 'SUCCESS' AS status, v_id AS new_movie_id;
END //

DELIMITER ;

USE movie_db;
DROP TRIGGER IF EXISTS trg_movies_bi;
DROP TRIGGER IF EXISTS trg_movies_bu;
DROP TRIGGER IF EXISTS trg_movies_ad;
DROP TRIGGER IF EXISTS trg_reviews_bi;
DROP TRIGGER IF EXISTS trg_reviews_ai;
DROP TRIGGER IF EXISTS trg_reviews_au;
DROP TRIGGER IF EXISTS trg_reviews_ad;

DELIMITER //

CREATE TRIGGER trg_movies_bi BEFORE INSERT ON movies FOR EACH ROW
BEGIN
    IF NEW.release_year > YEAR(CURDATE()) + 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Release year is too far in the future';
    END IF;
    IF NEW.release_date IS NOT NULL AND YEAR(NEW.release_date) <> NEW.release_year THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'release_date does not match release_year';
    END IF;
END //

CREATE TRIGGER trg_movies_bu BEFORE UPDATE ON movies FOR EACH ROW
BEGIN
    IF NEW.release_year > YEAR(CURDATE()) + 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Release year is too far in the future';
    END IF;
    IF NEW.release_date IS NOT NULL AND YEAR(NEW.release_date) <> NEW.release_year THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'release_date does not match release_year';
    END IF;
END //

CREATE TRIGGER trg_movies_ad AFTER DELETE ON movies FOR EACH ROW
BEGIN
    INSERT INTO movie_audit (movie_id, title, release_year, deleted_by)
    VALUES (OLD.movie_id, OLD.title, OLD.release_year, USER());
END //

CREATE TRIGGER trg_reviews_bi BEFORE INSERT ON reviews FOR EACH ROW
BEGIN
    IF NEW.review_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Review date cannot be in the future';
    END IF;
    IF EXISTS (SELECT 1 FROM reviews
               WHERE movie_id = NEW.movie_id AND reviewer_id = NEW.reviewer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reviewer has already reviewed this movie';
    END IF;
END //

CREATE TRIGGER trg_reviews_ai AFTER INSERT ON reviews FOR EACH ROW
BEGIN
    REPLACE INTO movie_rating_cache (movie_id, review_count, average_rating)
    SELECT NEW.movie_id, COUNT(*), ROUND(AVG(rating), 2)
    FROM reviews WHERE movie_id = NEW.movie_id;
END //

CREATE TRIGGER trg_reviews_au AFTER UPDATE ON reviews FOR EACH ROW
BEGIN
    REPLACE INTO movie_rating_cache (movie_id, review_count, average_rating)
    SELECT NEW.movie_id, COUNT(*), ROUND(AVG(rating), 2)
    FROM reviews WHERE movie_id = NEW.movie_id;
END //

CREATE TRIGGER trg_reviews_ad AFTER DELETE ON reviews FOR EACH ROW
BEGIN
    REPLACE INTO movie_rating_cache (movie_id, review_count, average_rating)
    SELECT OLD.movie_id, COUNT(*), ROUND(AVG(rating), 2)
    FROM reviews WHERE movie_id = OLD.movie_id;
END //

DELIMITER ;
