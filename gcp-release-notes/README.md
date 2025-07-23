# ✉️ GCP Daily Release Notes Summary

This script fetches Google Cloud Platform (GCP) release notes from the [official RSS feed](https://cloud.google.com/feeds/gcp-release-notes.xml), extracts product-specific announcements and features, summarizes them using Gemini, and sends a daily email digest using Resend. Can easily be deployed to serverless platforms like [Cloud Run](https://cloud.google.com/run?hl=en), [Railway](https://railway.app/?referralCode=alphasec), and others.

## ✨ Features

- 📰 Parses official [GCP Release Notes](https://cloud.google.com/release-notes)
- 📌 Includes only `Announcements` and `Features` (excludes `Fixes`, `Changed`, `Libraries` etc.)
- 🧠 Summarizes content for each product via [Gemini API](https://aistudio.google.com/app/apikey)
- ✉️ Sends formatted HTML email using [Resend](https://resend.com/api-keys)

## 🧰 Setup

1. Clone the repository.
2. Install dependencies: `pip install -r requirements.txt`
3. Set environment variables - export directly or use a .env file:
- `GCP_RELEASE_FEED_URL`: `https://cloud.google.com/feeds/gcp-release-notes.xml`
- `LOOKBACK_HOURS`: `24`
- `GOOGLE_API_KEY`: `your_gemini_api_key`
- `GEMINI_MODEL`: `gemini-2.0-flash`
- `RESEND_API_KEY`: `your_resend_api_key`
- `EMAIL_FROM`: `you@example.com`
- `EMAIL_TO`: `recipient@example.com`
4. Run the script: `python app.py`
5. Schedule a cron job to run at 07:30 UTC: `30 7 * * *`
