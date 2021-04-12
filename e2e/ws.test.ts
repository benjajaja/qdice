describe("Websocket", () => {
  test("should show offline", async () => {
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online",
    });

    await page.evaluate(() => (window as any).mqttClient.disconnect());

    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Offline",
    });
  });
  test("should reconnect", async () => {
    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Online",
    });

    await page.evaluate(() => (window as any).mqttClient.disconnect());

    await expect(page).toMatchElement(testId("connection-status"), {
      text: "Offline",
    });
  });
});
