import { test; suite } "mo:test";
import Principal "mo:base/Principal";
import Assets "../src/";
import Migrations "../src/Migrations";

actor {

  let canister_id = Principal.fromText("r7inp-6aaaa-aaaaa-aaabq-cai");
  let owner = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

  public func runTests() {
    suite(
      "Assets version tests",
      func() {
        test(
          "ensure init_stable_store() returns the current version",
          func() {

            let asset = Assets.init_stable_store(canister_id, owner);

            switch (asset) {
              // current version
              case (#v1_0_0(_)) assert true;
              case (_) assert false;
            };

            let _ = Migrations.get_current_state(asset); // should not if the version matches the current version

          },
        );

      },
    );
  };
};
