import * as assert from "assert";
import * as R from "ramda";
import * as helpers from "../helpers";
import { now, weekday } from "../timestamp";
import { Timestamp, TournamentFrequency } from "../types";

describe("Timestamp", function() {
  describe("weekday", () => {
    const aMonday = 1590996548815; // Mon 2020/06/01 09:29
    const msInDay = 86400000;
    it("should make weekdays", () => {
      assert.deepEqual(R.range(0, 7).map(i => 
        weekday(aMonday + i * msInDay)
      ), R.range(0, 7) );
    });
  });
});
