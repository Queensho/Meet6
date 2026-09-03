import json
import os
import sys
import tempfile

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = os.environ.get("PLAY_PACKAGE_NAME", "com.meet6.app")
TRACK = os.environ.get("PLAY_TRACK", "qa")
AAB_PATH = os.environ.get("PLAY_AAB_PATH", "build/app/outputs/bundle/release/app-release.aab")
VERSION_NAME = os.environ.get("RELEASE_VERSION_NAME", "1.0.0")
VERSION_CODE = os.environ.get("RELEASE_VERSION_CODE", "1")

raw_credentials = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
if not raw_credentials:
    raise SystemExit("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is missing")
if not os.path.isfile(AAB_PATH):
    raise SystemExit(f"AAB not found: {AAB_PATH}")

try:
    service_account_info = json.loads(raw_credentials)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: {exc}")

credentials = service_account.Credentials.from_service_account_info(
    service_account_info,
    scopes=["https://www.googleapis.com/auth/androidpublisher"],
)
service = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)

edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
edit_id = edit["id"]

try:
    media = MediaFileUpload(
        AAB_PATH,
        mimetype="application/octet-stream",
        resumable=True,
    )
    bundle = service.edits().bundles().upload(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        media_body=media,
    ).execute()
    uploaded_version_code = str(bundle.get("versionCode", VERSION_CODE))

    release_body = {
        "releases": [
            {
                "name": f"Meet6 {VERSION_NAME} ({uploaded_version_code})",
                "versionCodes": [uploaded_version_code],
                "status": "completed",
                "releaseNotes": [
                    {
                        "language": "tr-TR",
                        "text": "Meet6 ilk dahili test sürümü.",
                    }
                ],
            }
        ]
    }

    service.edits().tracks().update(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        track=TRACK,
        body=release_body,
    ).execute()

    result = service.edits().commit(
        packageName=PACKAGE_NAME,
        editId=edit_id,
    ).execute()
    print(
        json.dumps(
            {
                "ok": True,
                "packageName": PACKAGE_NAME,
                "track": TRACK,
                "versionCode": uploaded_version_code,
                "editId": result.get("id", edit_id),
            },
            ensure_ascii=False,
        )
    )
except Exception:
    try:
        service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
    except Exception:
        pass
    raise
