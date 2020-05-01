describe("Table", () => {
  test("go to different table", async () => {
    await expect(page).toClick(testId("go-to-table-Polo"), { timeout: 1000 });
    await expect(page).toMatchElement(testId("table-games-link"), {
      text: "Polo",
    });
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online on Polo",
    });
  });

  test(`open table directly: ${TEST_URL}/Polo`, async () => {
    await page.goto("about:blank", { waitUntil: "networkidle2" });
    await page.waitFor(1000);
    console.log("ok");
    await page.goto(`${TEST_URL}/Polo`, { waitUntil: "networkidle2" });
    await expect(page).toMatchElement(testId("table-games-link"), {
      text: "Polo",
    });
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online on Polo",
    });
  });
});
