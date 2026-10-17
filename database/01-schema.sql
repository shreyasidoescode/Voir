-- Movie Database Management System
-- File: 01_schema.sql
-- Compatible with MySQL 8.0+
-- Run this file first.

CREATE DATABASE IF NOT EXISTS movie_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;	

USE movie_db;

-- Drop in dependency order so this script can be rerun safely.
DROP VIEW IF EXISTS movie_review_summary;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS reviewers;
DROP TABLE IF EXISTS movie_credits;
DROP TABLE IF EXISTS movie_genres;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS people;
DROP TABLE IF EXISTS movies;

CREATE TABLE movies (
    movie_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    release_year SMALLINT UNSIGNED NOT NULL,
    release_date DATE NULL,
    country VARCHAR(100) NOT NULL,
    original_language VARCHAR(60) NOT NULL,
    runtime_minutes SMALLINT UNSIGNED NULL,
    synopsis VARCHAR(1000),
    CONSTRAINT chk_movie_year CHECK (release_year BETWEEN 1888 AND 2100),
    CONSTRAINT chk_movie_runtime CHECK (runtime_minutes IS NULL OR runtime_minutes > 0),
    INDEX idx_movies_title (title),
    INDEX idx_movies_year_country (release_year, country)
) ENGINE=InnoDB;

CREATE TABLE people (
    person_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(160) NOT NULL,
    birth_year SMALLINT UNSIGNED NULL,
    nationality VARCHAR(100) NULL,
    UNIQUE KEY uq_people_name_birth (full_name, birth_year),
    INDEX idx_people_name (full_name)
) ENGINE=InnoDB;

CREATE TABLE genres (
    genre_id INT AUTO_INCREMENT PRIMARY KEY,
    genre_name VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE movie_genres (
    movie_id INT NOT NULL,
    genre_id INT NOT NULL,
    PRIMARY KEY (movie_id, genre_id),
    CONSTRAINT fk_movie_genres_movie FOREIGN KEY (movie_id)
        REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_movie_genres_genre FOREIGN KEY (genre_id)
        REFERENCES genres(genre_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- A person can have different jobs on different films.
-- role_name examples: Director, Actor, Writer, Producer.
CREATE TABLE movie_credits (
    movie_id INT NOT NULL,
    person_id INT NOT NULL,
    role_name VARCHAR(40) NOT NULL,
    character_name VARCHAR(160) NULL,
    PRIMARY KEY (movie_id, person_id, role_name),
    CONSTRAINT fk_credits_movie FOREIGN KEY (movie_id)
        REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_credits_person FOREIGN KEY (person_id)
        REFERENCES people(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_credit_role CHECK (role_name IN
        ('Director', 'Actor', 'Writer', 'Producer', 'Composer', 'Cinematographer')),
    INDEX idx_credits_person_role (person_id, role_name)
) ENGINE=InnoDB;

CREATE TABLE reviewers (
    reviewer_id INT AUTO_INCREMENT PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(180) NOT NULL UNIQUE,
    join_date DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    movie_id INT NOT NULL,
    reviewer_id INT NOT NULL,
    rating DECIMAL(2,1) NOT NULL,
    review_text VARCHAR(1000) NOT NULL,
    review_date DATE NOT NULL,
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 0.5 AND 5.0),
    CONSTRAINT fk_reviews_movie FOREIGN KEY (movie_id)
        REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_reviewer FOREIGN KEY (reviewer_id)
        REFERENCES reviewers(reviewer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_reviews_movie_rating (movie_id, rating),
    INDEX idx_reviews_date (review_date)
) ENGINE=InnoDB;

-- A useful starter view for checking aggregate review scores.
CREATE VIEW movie_review_summary AS
SELECT
    m.movie_id,
    m.title,
    m.release_year,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.rating), 2) AS average_rating
FROM movies AS m
LEFT JOIN reviews AS r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.release_year;
