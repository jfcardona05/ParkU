"""Exercise the real public proxy with a browser HTTPS Origin (no tunnel needed)."""
import json
import os
import sys
import urllib.error
import urllib.request


def request(base, method, path, payload=None, token=None):
    headers = {
        "Origin": "https://parku-preview.invalid",
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = "Bearer " + token
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(base.rstrip("/") + path, body, headers, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        status = response.code
        try:
            data = json.loads(response.read().decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as error:
            raise AssertionError(f"API returned non-JSON HTTP {status}; check proxy/CORS") from error
    return status, data


def check(base):
    status, data = request(base, "POST", "/api/auth/login", {})
    assert status == 400 and data.get("code") == "INVALID_REQUEST", "Empty login did not reach Spring validation"
    status, data = request(
        base, "POST", "/api/auth/login",
        {"email": "public-smoke@example.invalid", "password": "intentionally-invalid"},
    )
    assert status == 401 and data.get("success") is False, "Bad credentials must return a JSON auth error"
    status, _ = request(base, "GET", "/api/wallet/balance")
    assert status == 401, "Anonymous wallet access must remain forbidden"
    email = os.environ.get("PARKU_TEST_EMAIL")
    password = os.environ.get("PARKU_TEST_PASSWORD")
    if email and password:
        status, data = request(base, "POST", "/api/auth/login", {"email": email, "password": password})
        assert status == 200 and data.get("token"), "Fixture login through proxy failed"
        token = data["token"]
        status, _ = request(base, "GET", "/api/wallet/balance", token=token)
        assert status == 200, "Proxy did not preserve Bearer authentication"
        status, _ = request(base, "GET", "/api/cash/current", token=token)
        assert status == 403, "Student fixture must not gain cashier permissions"
    print("Public API: HTTPS Origin, JSON errors, authentication and permissions passed")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/check-public-api.py http://127.0.0.1:8080/ACCESS_PATH")
    check(sys.argv[1])
