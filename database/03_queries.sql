USE movie_db;
--Movies released by Christopher Nolan in past 30 years
SELECT m.title,
       m.release_year,
       (SELECT GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ')
          FROM movie_genres mg
          JOIN genres g ON g.genre_id = mg.genre_id
         WHERE mg.movie_id = m.movie_id)              AS genres,
       s.average_rating,
       (SELECT GROUP_CONCAT(p.full_name ORDER BY p.full_name SEPARATOR ', ')
          FROM movie_credits c
          JOIN people p ON p.person_id = c.person_id
         WHERE c.movie_id = m.movie_id
           AND c.role_name = 'Actor')                 AS cast_members
FROM movies m
JOIN movie_credits d ON d.movie_id = m.movie_id AND d.role_name = 'Director'
JOIN people dp       ON dp.person_id = d.person_id
JOIN movie_review_summary s ON s.movie_id = m.movie_id
WHERE dp.full_name = 'Christopher Nolan'
ORDER BY m.release_year;

--SciFi movies released in India after 2015
SELECT m.title, m.release_year, m.original_language
FROM movies m
JOIN movie_genres mg ON mg.movie_id = m.movie_id
JOIN genres g        ON g.genre_id = mg.genre_id
WHERE m.country = 'India'
  AND g.genre_name = 'Sci-Fi'
  AND m.release_year > 2015;

--SciFi movies released in India        
SELECT m.title, m.release_year, m.original_language
FROM movies m
JOIN movie_genres mg ON mg.movie_id = m.movie_id
JOIN genres g        ON g.genre_id = mg.genre_id
WHERE m.country = 'India'
  AND g.genre_name = 'Sci-Fi'
ORDER BY m.release_year;

--Thriller movies released in Indian after 2015
SELECT m.title, m.release_year, m.original_language
FROM movies m
JOIN movie_genres mg ON mg.movie_id = m.movie_id
JOIN genres g        ON g.genre_id = mg.genre_id
WHERE m.country = 'India'
  AND g.genre_name = 'Thriller'
  AND m.release_year > 2015
ORDER BY m.release_year;

--Actors who have worked with both Christian Bale and Heath Ledger
SELECT p.full_name AS actor
FROM movie_credits c1
JOIN people p          ON p.person_id = c1.person_id
JOIN movie_credits c2  ON c2.movie_id = c1.movie_id
                      AND c2.role_name = 'Actor'
                      AND c2.person_id <> c1.person_id
JOIN people a          ON a.person_id = c2.person_id
                      AND a.full_name IN ('Christian Bale', 'Heath Ledger')
WHERE c1.role_name = 'Actor'
  AND p.full_name NOT IN ('Christian Bale', 'Heath Ledger')
GROUP BY p.person_id, p.full_name
HAVING COUNT(DISTINCT a.person_id) = 2
ORDER BY p.full_name;

--Christopher Nolans movies in which Christian Bale has acted 
SELECT m.title, m.release_year, d.full_name AS director, a.full_name AS actor
FROM movies m
JOIN movie_credits dc ON dc.movie_id = m.movie_id AND dc.role_name = 'Director'
JOIN people d         ON d.person_id = dc.person_id AND d.full_name = 'Christopher Nolan'
JOIN movie_credits mc ON mc.movie_id = m.movie_id AND mc.role_name = 'Actor'
JOIN people a         ON a.person_id = mc.person_id AND a.full_name = 'Christian Bale'
ORDER BY m.release_year;

--Movies with average rating greater than or equal to 4.25
SELECT s.title, s.release_year, s.review_count, s.average_rating
FROM movie_review_summary s
WHERE s.average_rating >= 4.25
  AND s.review_count <= (SELECT AVG(review_count) FROM movie_review_summary)
ORDER BY s.average_rating DESC, s.title;

 --Movies similar to Inception(genre comparison)
 WITH target AS (
    SELECT movie_id FROM movies WHERE title = 'Inception'
),
shared_genres AS (
    SELECT mg2.movie_id,
           COUNT(*) AS n,
           GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ') AS names
    FROM movie_genres mg1
    JOIN movie_genres mg2 ON mg2.genre_id = mg1.genre_id
                         AND mg2.movie_id <> mg1.movie_id
    JOIN genres g         ON g.genre_id = mg1.genre_id
    WHERE mg1.movie_id = (SELECT movie_id FROM target)
    GROUP BY mg2.movie_id
),
shared_crew AS (
    SELECT c2.movie_id,
           COUNT(*) AS n,
           GROUP_CONCAT(CONCAT(p.full_name, ' (', c2.role_name, ')')
                        ORDER BY p.full_name SEPARATOR ', ') AS names
    FROM movie_credits c1
    JOIN movie_credits c2 ON c2.person_id = c1.person_id
                         AND c2.role_name = c1.role_name
                         AND c2.movie_id <> c1.movie_id
    JOIN people p         ON p.person_id = c1.person_id
    WHERE c1.movie_id = (SELECT movie_id FROM target)
    GROUP BY c2.movie_id
)
SELECT m.title,
       m.release_year,
       COALESCE(sg.n, 0) + 2 * COALESCE(sc.n, 0)  AS similarity_score,
       CONCAT_WS(' | ',
                 CASE WHEN sg.n IS NOT NULL THEN CONCAT('Shared genres: ', sg.names) END,
                 CASE WHEN sc.n IS NOT NULL THEN CONCAT('Shared crew: ', sc.names) END)
                                                  AS reason
FROM movies m
LEFT JOIN shared_genres sg ON sg.movie_id = m.movie_id
LEFT JOIN shared_crew   sc ON sc.movie_id = m.movie_id
WHERE m.movie_id <> (SELECT movie_id FROM target)
  AND (sg.n IS NOT NULL OR sc.n IS NOT NULL)
ORDER BY similarity_score DESC, m.title
LIMIT 5;

--Movies with dark in title
SELECT movie_id, title, release_year, country, original_language
FROM movies
WHERE title LIKE '%dark%'
ORDER BY title;

--Movies in which Aamir Khan has acted
SELECT p.full_name, m.title, m.release_year, c.role_name
FROM people p
JOIN movie_credits c ON c.person_id = p.person_id
JOIN movies m        ON m.movie_id = c.movie_id
WHERE p.full_name = 'Aamir Khan'
ORDER BY m.release_year;

--Films in hindi after 2010 with average rating above 4
SELECT m.title, m.release_year, m.original_language, s.average_rating
FROM movies m
JOIN movie_genres mg        ON mg.movie_id = m.movie_id
JOIN genres g               ON g.genre_id = mg.genre_id
JOIN movie_review_summary s ON s.movie_id = m.movie_id
WHERE g.genre_name = 'Drama'
  AND m.original_language = 'Hindi'
  AND m.release_year >= 2010
  AND s.average_rating >= 4.0
ORDER BY s.average_rating DESC, m.title;

--All details of the movie The Dark Knight
SELECT m.title,
       m.release_year,
       m.country,
       m.original_language,
       m.runtime_minutes,
       (SELECT GROUP_CONCAT(p.full_name SEPARATOR ', ')
          FROM movie_credits c JOIN people p ON p.person_id = c.person_id
         WHERE c.movie_id = m.movie_id AND c.role_name = 'Director')  AS director,
       (SELECT GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ')
          FROM movie_genres mg JOIN genres g ON g.genre_id = mg.genre_id
         WHERE mg.movie_id = m.movie_id)                              AS genres,
       (SELECT GROUP_CONCAT(p.full_name ORDER BY p.full_name SEPARATOR ', ')
          FROM movie_credits c JOIN people p ON p.person_id = c.person_id
         WHERE c.movie_id = m.movie_id AND c.role_name = 'Actor')     AS cast_members,
       s.review_count,
       s.average_rating
FROM movies m
JOIN movie_review_summary s ON s.movie_id = m.movie_id
WHERE m.title = 'The Dark Knight';

-- Movies directed by Rajkumar Hirani 
SELECT m.title, m.release_year, m.runtime_minutes, s.average_rating
FROM movies m
JOIN movie_credits c        ON c.movie_id = m.movie_id AND c.role_name = 'Director'
JOIN people p               ON p.person_id = c.person_id
JOIN movie_review_summary s ON s.movie_id = m.movie_id
WHERE p.full_name = 'Rajkumar Hirani'
ORDER BY m.release_year DESC;

--- Movies done by Khans
SELECT p.full_name, c.role_name, m.title, m.release_year
FROM people p
JOIN movie_credits c ON c.person_id = p.person_id
JOIN movies m        ON m.movie_id = c.movie_id
WHERE p.full_name LIKE '%Khan%'
ORDER BY p.full_name, m.release_year;

-- Genres with movie count and average rating of movies
SELECT g.genre_name,
       COUNT(*)                     AS movie_count,
       ROUND(AVG(s.average_rating), 2) AS avg_rating
FROM genres g
JOIN movie_genres mg        ON mg.genre_id = g.genre_id
JOIN movie_review_summary s ON s.movie_id = mg.movie_id
GROUP BY g.genre_id, g.genre_name
ORDER BY movie_count DESC, g.genre_name;

-- Countries with original language number of movies, average runtime and average rating
SELECT m.country,
       m.original_language,
       COUNT(*)                          AS movies,
       ROUND(AVG(m.runtime_minutes), 1)  AS avg_runtime,
       ROUND(AVG(s.average_rating), 2)   AS avg_rating
FROM movies m
JOIN movie_review_summary s ON s.movie_id = m.movie_id
GROUP BY m.country, m.original_language
ORDER BY movies DESC, m.country;

-- 5 movies with their release year review count and average rating 
SELECT title, release_year, review_count, average_rating
FROM movie_review_summary
WHERE review_count > 0
ORDER BY average_rating DESC, review_count DESC, title
LIMIT 5;

-- Directors, movies directed and average ratings of movies.
SELECT p.full_name AS director,
       COUNT(*)                       AS movies_directed,
       ROUND(AVG(s.average_rating), 2) AS avg_rating_of_their_movies
FROM people p
JOIN movie_credits c        ON c.person_id = p.person_id AND c.role_name = 'Director'
JOIN movie_review_summary s ON s.movie_id = c.movie_id
GROUP BY p.person_id, p.full_name
ORDER BY movies_directed DESC, avg_rating_of_their_movies DESC, p.full_name
LIMIT 10;

-- Actors grouped with their movies
SELECT p.full_name AS actor,
       COUNT(*)    AS movie_count,
       GROUP_CONCAT(m.title ORDER BY m.release_year SEPARATOR ', ') AS movies
FROM people p
JOIN movie_credits c ON c.person_id = p.person_id AND c.role_name = 'Actor'
JOIN movies m        ON m.movie_id = c.movie_id
GROUP BY p.person_id, p.full_name
HAVING COUNT(*) > 1
ORDER BY movie_count DESC, p.full_name;
 
SELECT s.title, s.release_year, s.average_rating
FROM movie_review_summary s
WHERE s.average_rating > (SELECT AVG(rating) FROM reviews)
ORDER BY s.average_rating DESC, s.title;
 
SELECT m.country, m.title, s.average_rating
FROM movies m
JOIN movie_review_summary s ON s.movie_id = m.movie_id
WHERE s.average_rating > (
        SELECT AVG(s2.average_rating)
        FROM movies m2
        JOIN movie_review_summary s2 ON s2.movie_id = m2.movie_id
        WHERE m2.country = m.country)
ORDER BY m.country, s.average_rating DESC, m.title;
 
WITH ranked AS (
    SELECT g.genre_name,
           m.title,
           s.average_rating,
           RANK() OVER (PARTITION BY g.genre_id
                        ORDER BY s.average_rating DESC, m.title) AS rnk
    FROM genres g
    JOIN movie_genres mg        ON mg.genre_id = g.genre_id
    JOIN movies m               ON m.movie_id = mg.movie_id
    JOIN movie_review_summary s ON s.movie_id = m.movie_id
)
SELECT genre_name, title AS top_movie, average_rating
FROM ranked
WHERE rnk = 1
ORDER BY genre_name;


CREATE OR REPLACE VIEW v_movie_details AS
SELECT m.movie_id,
       m.title,
       m.release_year,
       m.country,
       m.original_language,
       m.runtime_minutes,
       (SELECT GROUP_CONCAT(p.full_name SEPARATOR ', ')
          FROM movie_credits c JOIN people p ON p.person_id = c.person_id
         WHERE c.movie_id = m.movie_id AND c.role_name = 'Director')  AS director,
       (SELECT GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ')
          FROM movie_genres mg JOIN genres g ON g.genre_id = mg.genre_id
         WHERE mg.movie_id = m.movie_id)                              AS genres,
       (SELECT GROUP_CONCAT(p.full_name ORDER BY p.full_name SEPARATOR ', ')
          FROM movie_credits c JOIN people p ON p.person_id = c.person_id
         WHERE c.movie_id = m.movie_id AND c.role_name = 'Actor')     AS cast_members,
       s.review_count,
       s.average_rating
FROM movies m
JOIN movie_review_summary s ON s.movie_id = m.movie_id;


CREATE OR REPLACE VIEW v_person_filmography AS
SELECT p.person_id,
       p.full_name,
       p.nationality,
       c.role_name,
       c.character_name,
       m.movie_id,
       m.title,
       m.release_year
FROM people p
JOIN movie_credits c ON c.person_id = p.person_id
JOIN movies m        ON m.movie_id = c.movie_id;


CREATE OR REPLACE VIEW v_genre_statistics AS
SELECT g.genre_id,
       g.genre_name,
       COUNT(DISTINCT mg.movie_id)      AS movie_count,
       ROUND(AVG(s.average_rating), 2)  AS avg_rating,
       MIN(m.release_year)              AS earliest_year,
       MAX(m.release_year)              AS latest_year
FROM genres g
LEFT JOIN movie_genres mg        ON mg.genre_id = g.genre_id
LEFT JOIN movies m               ON m.movie_id = mg.movie_id
LEFT JOIN movie_review_summary s ON s.movie_id = m.movie_id
GROUP BY g.genre_id, g.genre_name;
 
SELECT title, director, genres, average_rating
FROM v_movie_details
WHERE original_language = 'Hindi' AND average_rating >= 4.0
ORDER BY average_rating DESC, title;

       
SELECT full_name, role_name, title, release_year
FROM v_person_filmography
WHERE full_name = 'Christian Bale'
ORDER BY release_year;

-- Movies released in India after 2015
SELECT title, release_year
FROM movies
WHERE country = 'India' AND release_year > 2015;

-- All movies by Christopher Nolan
SELECT m.title
FROM movies m
JOIN movie_credits d ON d.movie_id = m.movie_id AND d.role_name = 'Director'
JOIN people n        ON n.person_id = d.person_id AND n.full_name = 'Christopher Nolan';

--unreviewed movies
SELECT movie_id FROM movies
WHERE movie_id NOT IN (SELECT movie_id FROM reviews);
 
SELECT g.genre_name, COUNT(mg.movie_id) AS movie_count
FROM genres g
JOIN movie_genres mg ON mg.genre_id = g.genre_id
GROUP BY g.genre_name;



