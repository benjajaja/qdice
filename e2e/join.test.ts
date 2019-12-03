describe("Join", () => {
  test("should join and leave a game", async () => {
    await expect(page).toClick(testId("button-seat"));
    await expect(page).toMatchElement(testId("login-dialog"));

    await expect(page).toFill(testId("login-input"), "puppet");
    await expect(page).toClick(testId("login-login"), { text: "Play" });

    await expect(page).not.toMatchElement(testId("login-dialog"));

    await expect(page).toMatchElement(testId("player-name-0"), {
      text: "puppet",
    });

    await expect(page).toClick(testId("button-seat"), { text: "Leave" });
    await expect(page).not.toMatchElement(testId("player-name-0"), {
      text: "puppet",
    });
  });
});
