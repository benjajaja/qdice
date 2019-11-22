describe('Table', () => {
  test('go to different table', async () => {
    await expect(page).toClick(testId('go-to-table-Melchor'), {timeout: 1000});
    await expect(page).toMatch('Table Melchor');
  });
});
