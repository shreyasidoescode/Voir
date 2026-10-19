import re
import mysql.connector
from mysql.connector import Error
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="YOUR_PASSWORD",
    database="movie_db"
)
cur = db.cursor()


def show(proc, args):
    cur.callproc(proc, args)
    found = False
    for res in cur.stored_results():
        cols = [c[0] for c in res.description]
        rows = res.fetchall()
        if rows:
            found = True
            print("  " + " | ".join(cols))
            for row in rows:
                print("  " + " | ".join(str(v) for v in row))
    if not found:
        print("  No results found.")
    db.commit()


def find_movie():
    title = input("Movie title (or part of it): ").strip()
    if not title:
        return None
    cur.execute(
        "SELECT movie_id, title, release_year FROM movies "
        "WHERE title LIKE %s ORDER BY title",
        (f"%{title}%",)
    )
    rows = cur.fetchall()
    if not rows:
        print("  No movies found.")
        return None
    for mid, t, y in rows:
        print(f"  [{mid}] {t} ({y})")
    if len(rows) == 1:
        return rows[0][0]
    try:
        return int(input("Enter the movie id: "))
    except ValueError:
        print("  Invalid id.")
        return None


COUNTRIES = {
    "indian": "India", "india": "India",
    "american": "United States", "usa": "United States",
    "korean": "South Korea", "japanese": "Japan",
    "british": "United Kingdom", "australian": "Australia"
}


def parse(text):
    t = text.lower()
    country = next((v for k, v in COUNTRIES.items()
                    if re.search(rf"\b{k}\b", t)), None)
    year = re.search(r"\b((?:19|20)\d{2})\b", t)
    rating = re.search(r"(?:above|over|more than)\s+(\d+(?:\.\d+)?)", t)
    return (country,
            int(year.group(1)) if year else None,
            None,
            float(rating.group(1)) if rating else None,
            None)


print("=== Voir: Movie Database Console ===")
while True:
    print("\n1. Ask in one line")
    print("2. Director filmography")
    print("3. Add a review")
    print("4. Exit")
    choice = input("Choose: ").strip()
    try:
        if choice == "1":
            q = input("Ask (e.g. Tell me indian movies released in 2015): ")
            args = parse(q)
            print("Understood:", args)
            show("search_movies", args)
        elif choice == "2":
            show("get_movies_by_director", (input("Director name: "),))
        elif choice == "3":
            mid = find_movie()
            if mid:
                show("add_review", (
                    mid,
                    int(input("Reviewer id: ")),
                    float(input("Rating (0.5-5.0): ")),
                    input("Review text: ")
                ))
        elif choice == "4":
            print("Happy Movie Watching!")
            break
        else:
            print("Invalid choice.")
    except Error as e:
        print("Database error:", e.msg)
    except ValueError:
        print("Please enter a valid number.")

cur.close()
db.close()
