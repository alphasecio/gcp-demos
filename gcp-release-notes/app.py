import os
import re
import resend
import feedparser
import google.genai as genai
from datetime import datetime, timedelta, timezone
from dateutil.parser import parse as parse_datetime
from bs4 import BeautifulSoup

FEED_URL = os.getenv("GCP_RELEASE_FEED_URL", "https://cloud.google.com/feeds/gcp-release-notes.xml")
LOOKBACK_HOURS = int(os.getenv("LOOKBACK_HOURS", "24"))
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
EMAIL_FROM = os.getenv("EMAIL_FROM")
EMAIL_TO = os.getenv("EMAIL_TO")

def fetch_recent_entries(since_hours=LOOKBACK_HOURS):
    feed = feedparser.parse(FEED_URL)
    cutoff = datetime.now(timezone.utc) - timedelta(hours=since_hours)

    entries = []
    for entry in feed.entries:
        try:
            published = parse_datetime(entry.updated).astimezone(timezone.utc)
        except Exception:
            continue

        if published > cutoff:
            link = entry.get("link") or getattr(entry, "link", None)
            if isinstance(link, dict) and "href" in link:
                link = link["href"]
            if not isinstance(link, str):
                link = None
            
            content_html = entry.get("content", [{}])[0].get("value", "")
            entries.append({
                "title": entry.get("title", "Untitled"),
                "published": published,
                "link": link,
                "content_html": content_html,
            })

    return entries

def extract_structured_info(entry):
    soup = BeautifulSoup(entry["content_html"], "html.parser")
    sections = []

    for h2 in soup.find_all("h2", class_="release-note-product-title"):
        product = h2.get_text(strip=True)
        category = None
        details_by_category = {"Announcement": [], "Feature": []}

        for sib in h2.find_next_siblings():
            if sib.name == "h2":
                break  # next product block

            if sib.name == "h3":
                cat = sib.get_text(strip=True)
                if cat in {"Announcement", "Feature"}:
                    category = cat
                else:
                    category = None  # skip unsupported categories
            elif sib.name == "p" and category:
                paragraph = sib.get_text(strip=True)
                if paragraph:
                    details_by_category[category].append(paragraph)

        for cat in ["Announcement", "Feature"]:
            if details_by_category[cat]:
                sections.append({
                    "product": product,
                    "category": cat,
                    "details": details_by_category[cat],
                })

    return sections

def summarize_with_gemini(releases):
    genai_client = genai.Client(api_key=GOOGLE_API_KEY)
    prompt_lines = [
        "Create a clean, readable HTML email summary of the following GCP release notes.",
        "Use the format below with <strong> for product names, and wrap the summaries in <ul><li> bullets.",
        "Example:",
        "<strong>Product Name</strong>",
        "<ul><li>Brief summary of feature or announcement</li></ul>",
        "",
        "Only include features and announcements. Keep each bullet short (1–2 lines max).",
        "Now summarize:"
    ]

    for release in sorted(releases, key=lambda r: r["product"]):
        product = release["product"]
        details = release["details"]
        prompt_lines.append(f"<strong>{product}</strong>")
        prompt_lines.append("<ul>")
        for item in details:
            prompt_lines.append(f"<li>{item.strip()}</li>")
        prompt_lines.append("</ul>")

    prompt = "\n".join(prompt_lines)

    response = genai_client.models.generate_content(
        model=GEMINI_MODEL,
        contents=prompt,
    )

    output = response.text.strip()

    if output.startswith("```html"):
        output = output[len("```html"):].strip()
    if output.endswith("```"):
        output = output[:-len("```")].strip()

    return output

def send_email(email_subject: str, email_body: str):
    resend.api_key = RESEND_API_KEY       
    email = resend.Emails.send({
        "from": EMAIL_FROM,
        "to": [EMAIL_TO],
        "subject": email_subject,
        "html": email_body,
        "text": re.sub(r"<[^>]+>", "", email_body),
    })
    print(f"Email sent to {EMAIL_TO} successfully!")

if __name__ == "__main__":
    entries = fetch_recent_entries()
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%B %d, %Y")
  
    if not entries:
        subject = f"🛠️ GCP Release Notes – {yesterday}"
        body = "No new GCP release notes were published in the past 24 hours."
        send_email(subject, body)
    else:
        structured = []
        for entry in entries:
            structured += extract_structured_info(entry)
        summary = summarize_with_gemini(structured)
        
        summary_link = next((e.get("link") for e in entries if "link" in e and e["link"]), None)
        if summary_link:
            summary_html = f'<p><a href="{summary_link}">GCP Release Notes Summary</a></p>\n' + summary
        else:
            summary_html = summary
        
        subject = f"🛠️ GCP Release Notes – {yesterday}"
        send_email(subject, summary_html)
