describe("Table", () => {
  test("go to different table", async () => {
    await expect(page).toClick(testId("go-to-table-Lagos"), { timeout: 1000 });
    await expect(page).toMatchElement(testId("table-games-link"), {
      text: "Lagos",
    });
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online on Lagos",
    });
  });

  test(`open table directly: ${TEST_URL}/Lagos`, async () => {
    await page.goto("about:blank", { waitUntil: "networkidle2" });
    await page.waitFor(1000);
    console.log("ok");
    await page.goto(`${TEST_URL}/Lagos`, { waitUntil: "networkidle2" });
    await expect(page).toMatchElement(testId("table-games-link"), {
      text: "Lagos",
    });
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online on Lagos",
    });
  });
});
