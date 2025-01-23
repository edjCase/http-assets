import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Option "mo:base/Option";

import { test; suite } "mo:test";
import Sha256 "mo:sha2/Sha256";
import Vector "mo:vector";
import Map "mo:map/Map";
import Set "mo:map/Set";
import Itertools "mo:itertools/Iter";
import MemoryRegion "mo:memory-region/MemoryRegion";

import FileSystem "../src/BaseAssets/FileSystem";
import Asset "../src/BaseAssets/FileSystem/Asset";
import Utils "../src/BaseAssets/Utils";

test(
    "format key",
    func() {

        assert Utils.format_key("path/to/file") == "/path/to/file";
        assert Utils.format_key("/path/to/file") == "/path/to/file";
        assert Utils.format_key("path/to/file/") == "/path/to/file";
        assert Utils.format_key("/path/to/file/") == "/path/to/file";
        assert Utils.format_key("path/to/file//") == "/path/to/file";
        assert Utils.format_key("/path/to/file//") == "/path/to/file";

    },
);
