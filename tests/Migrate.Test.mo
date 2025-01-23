import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

import { test; suite } "mo:test";
import Sha256 "mo:sha2/Sha256";
import Vector "mo:vector";
import Map "mo:map/Map";

import BaseAssets "../src/BaseAssets";
import Assets "../src/";
import Migrations "../src/Migrations";

import V0_types "../src/Migrations/V0/types";
import V0_upgrade "../src/Migrations/V0/upgrade";

import V0_1_0_types "../src/Migrations/V0_1_0/types";
import V0_1_0_upgrade "../src/Migrations/V0_1_0/upgrade";

actor {
    let { thash; nhash } = Map;

    let canister_id = Principal.fromText("r7inp-6aaaa-aaaaa-aaabq-cai");
    let owner = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
    let caller = Principal.fromText("tde7l-3qaaa-aaaah-qansa-cai");

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
                            case (#v0_3_0(internal_state)) assert true;
                            case (_) assert false;
                        };

                        let internal_state = Migrations.get_current_state(asset); // should not if the version matches the current version

                    },
                );

            },
        );
    };
};
