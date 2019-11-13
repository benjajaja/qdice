describe('Home', () => {
  it('should set title', async () => {
    const title = await page.title();
    expect(title).toBe("Qdice.wtf");
  });


  it('should display "Table..." text on page', async () => {
    await expect(page).toMatch('Table España')
  });

  it('should display "join" button on page', async () => {
    await expect(page).toMatchElement(".edButton.edGameHeader__button", { text: "Join" })
  });

  it('should display and close the login dialog', async () => {
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog");

    await expect(page).toMatchElement(".edLoginDialog__buttons button", { text: "Close" });
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(1)");

    await expect(page).not.toMatchElement(".edLoginDialog", { timeout: 2000 });
  });

});

describe('Join', () => {
  it('should join and leave a game', async () => {
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog");

    await expect(page).toFill(".edLoginDialog form input", "puppet");
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(2)");

    await expect(page).not.toMatchElement(".edLoginDialog");
    await expect(page).toMatchElement(".edPlayerChip__name", { text: "puppet" });

    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Leave" });
    await expect(page).not.toMatchElement(".edPlayerChip__name", { text: "puppet" });
  });

});

