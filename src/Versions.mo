import V0 "Migrations/V0/types";
import V0_1_0_types "Migrations/V0_1_0/types";
import V0_2_0_types "Migrations/V0_2_0/types";

module {
    public type VersionedStableStore = {
        #v0 : V0.StableStore;
        #v0_1_0 : V0_1_0_types.StableStore;
        #v0_2_0 : V0_2_0_types.StableStore;
    };

};
