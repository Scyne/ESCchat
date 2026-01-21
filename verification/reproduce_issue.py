from playwright.sync_api import sync_playwright
import time

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--use-fake-device-for-media-stream",
                "--use-fake-ui-for-media-stream",
                "--no-sandbox"
            ]
        )

        # User A (Sender)
        context_a = browser.new_context(permissions=["microphone", "camera"])
        page_a = context_a.new_page()
        page_a.goto("http://localhost:8443/group/test")

        # Login A
        page_a.get_by_label("Username", exact=True).fill("UserA")
        page_a.get_by_role("button", name="Connect").click()

        # Wait for A to join
        page_a.wait_for_selector("#userspan")

        # User B (Receiver)
        context_b = browser.new_context(permissions=["microphone", "camera"])
        page_b = context_b.new_page()
        page_b.goto("http://localhost:8443/group/test")

        # Login B
        page_b.get_by_label("Username", exact=True).fill("UserB")
        page_b.get_by_role("button", name="Connect").click()

        # Wait for connection and streams
        page_b.wait_for_selector("#userspan")
        # Wait for media element to appear
        page_b.wait_for_selector("video.media", state="attached")

        # Wait a bit for things to settle
        time.sleep(2)

        # Check initial mute state (should be unmuted)
        initial_muted = page_b.evaluate("""() => {
            const media = document.querySelectorAll('video.media');
            const results = [];
            media.forEach(m => {
                if (!m.id.startsWith('media-')) return;
                // Exclude local camera if present (usually local camera has muted=true, but here we check remote)
                // In galene, local video is also in .media but has different properties.
                // Remote video IDs: media-<userid>
                results.push({id: m.id, muted: m.muted});
            });
            return results;
        }""")
        print(f"Initial: {initial_muted}")

        # User B changes status to Away
        print("Changing status to Away...")
        page_b.evaluate("setStatus('Away')")
        time.sleep(1)

        # Check mute state and UI class
        muted_away = page_b.evaluate("""() => {
            const media = document.querySelectorAll('video.media');
            const results = [];
            media.forEach(m => {
                if (!m.id.startsWith('media-')) return;
                const controls = document.getElementById('controls-' + m.id.split('-')[1]);
                let ui_class = '';
                if (controls) {
                    const btn = controls.querySelector('.volume-mute');
                    if (btn) ui_class = btn.className;
                }
                results.push({id: m.id, muted: m.muted, ui: ui_class});
            });
            return results;
        }""")
        print(f"Status Away: {muted_away}")

        # User B changes status to Online
        print("Changing status to Online...")
        page_b.evaluate("setStatus('Online')")
        time.sleep(1)

        # Check mute state and UI class
        muted_online = page_b.evaluate("""() => {
            const media = document.querySelectorAll('video.media');
            const results = [];
            media.forEach(m => {
                if (!m.id.startsWith('media-')) return;
                const controls = document.getElementById('controls-' + m.id.split('-')[1]);
                let ui_class = '';
                if (controls) {
                    const btn = controls.querySelector('.volume-mute');
                    if (btn) ui_class = btn.className;
                }
                results.push({id: m.id, muted: m.muted, ui: ui_class});
            });
            return results;
        }""")
        print(f"Status Online: {muted_online}")

        page_b.screenshot(path="verification/verification.png")

        browser.close()

if __name__ == "__main__":
    run()
