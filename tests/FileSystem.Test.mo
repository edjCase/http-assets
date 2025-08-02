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
import Encoding "../src/BaseAssets/FileSystem/Encoding";

actor {
  let { thash; nhash } = Map;

  func file_exists(root : FileSystem.Directory, file_path : Text) : Bool {
    let paths_iter = Itertools.peekable(Text.split(file_path, #text("/")));

    switch (paths_iter.peek()) {
      case (?("")) ignore paths_iter.next();
      case (_) {};
    };

    var map = root;

    for (path in paths_iter) {
      map := switch (Map.get(map, thash, path)) {
        case (?#Directory(map)) map;
        case (?#Asset(asset)) return Option.isNull(paths_iter.next());
        case (null) return false;
      };
    };

    false;
  };

  let region = MemoryRegion.new();
  let fs = FileSystem.new(region);

  public func runTests() {
    suite(
      "FileSystem",
      func() {
        suite(
          "Hierachical Storage System",
          func() {
            test(
              "create_asset() creates a new asset and the nested directories",
              func() {

                let #ok(asset) = FileSystem.create_asset(fs, "/assets/images/logo.png");
                assert file_exists(fs.root, "/assets/images/logo.png");

                let #ok(_) = FileSystem.create_asset(fs, "assets/images/wallpaper.png");
                assert file_exists(fs.root, "/assets/images/wallpaper.png");

                let #ok(_) = FileSystem.create_asset(fs, "/assets/images/avatars/avatar.png");
                assert file_exists(fs.root, "/assets/images/avatars/avatar.png");

              },
            );

            test(
              "create_asset() fails if file path is invalid",
              func() {
                let #err(_) = FileSystem.create_asset(fs, "/assets/images//logo.png");
                assert not file_exists(fs.root, "/assets/images//logo.png");

              },
            );

            test(
              "create_asset() fails if a file exists in the path",
              func() {
                let #ok(_) = FileSystem.create_asset(fs, "/assets/songs/solo.mp3");
                assert file_exists(fs.root, "/assets/songs/solo.mp3");

                let #err(_) = FileSystem.create_asset(fs, "/assets/songs/solo.mp3/lyrics.txt");
                assert not file_exists(fs.root, "/assets/songs/solo.mp3/lyrics.txt");

              },
            );

            test(
              "create_asset() fails if the asset already exists",
              func() {

                let #ok(_) = FileSystem.create_asset(fs, "/assets/videos/dune.mp4");
                assert file_exists(fs.root, "/assets/videos/dune.mp4");

                let #err(_) = FileSystem.create_asset(fs, "/assets/videos/dune.mp4");
                assert file_exists(fs.root, "/assets/videos/dune.mp4");

              },
            );

            test(
              "create_asset() fails if directory exists in position of the file",
              func() {
                let #ok(_) = FileSystem.create_asset(fs, "/assets/web/index.html");
                assert file_exists(fs.root, "/assets/web/index.html");

                let #err(_) = FileSystem.create_asset(fs, "/assets/web");
                assert not file_exists(fs.root, "/assets/web");

              },
            );

            test(
              "get_asset() returns the asset if it exists",
              func() {
                let #ok(?(logo)) = FileSystem.get_asset(fs, "assets/images/logo.png") else return assert false;
                let #ok(?(wallpaper)) = FileSystem.get_asset(fs, "assets/images/wallpaper.png") else return assert false;
                let #ok(?(avatar)) = FileSystem.get_asset(fs, "/assets/images/avatars/avatar.png") else return assert false;
                let #ok(?(dune)) = FileSystem.get_asset(fs, "/assets/videos/dune.mp4") else return assert false;
                let #ok(?(index)) = FileSystem.get_asset(fs, "/assets/web/index.html") else return assert false;

              },
            );

            test(
              "get_asset() returns #err() if the path is invalid, another file or directory exists in the path",
              func() {
                let #err(_) = FileSystem.get_asset(fs, "/assets/images/logo.png/"); // invalid path
                let #err(_) = FileSystem.get_asset(fs, "/assets/images/wallpaper.png/lyrics.txt"); // another file exists
                let #err(_) = FileSystem.get_asset(fs, "/assets/images"); // another directory exists
              },
            );

            test(
              "get_asset() returns null if the asset does not exist",
              func() {
                let #ok(null) = FileSystem.get_asset(fs, "/assets/random/asset.jpg") else return assert false;
                let #ok(null) = FileSystem.get_asset(fs, "/assets/missing/folder/avatar.jpg") else return assert false;
              },
            );

            test(
              "toArray() return all the assets in the hierarchy",
              func() {

                let assets = FileSystem.to_array(fs);
                assert assets.size() == 6;

                let keys = Iter.map<(Text, Any), Text>(assets.vals(), func(key : Text, _ : Any) : Text { key });

                let set = Set.fromIter<Text>(keys, thash);

                assert Set.has(set, thash, "/assets/images/logo.png");
                assert Set.has(set, thash, "/assets/images/wallpaper.png");
                assert Set.has(set, thash, "/assets/images/avatars/avatar.png");
                assert Set.has(set, thash, "/assets/videos/dune.mp4");
                assert Set.has(set, thash, "/assets/web/index.html");
                assert Set.has(set, thash, "/assets/songs/solo.mp3");

              },
            );
          },
        );

        suite(
          "file system insertions",
          func() {
            test(
              "Insert a new asset into the file system",
              func() {
                let asset = Asset.new();

                asset.content_type := "image/png";
                asset.is_aliased := ?true;
                asset.max_age := ?3600;
                asset.allow_raw_access := ?false;

                ignore Asset.create_encoding(fs, asset, "gzip", "logo-image" : Blob, "sha256-hash" : Blob);

                let #ok(_) = FileSystem.insert_asset(fs, "/assets/images/logo.png", asset) else return assert false;

                let #ok(?(logo)) = FileSystem.get_asset(fs, "/assets/images/logo.png") else return assert false;

                assert logo.content_type == "image/png";
                assert logo.is_aliased == ?true;
                assert logo.max_age == ?3600;
                assert logo.allow_raw_access == ?false;

                let ?encoding = Asset.get_encoding(fs, logo, "gzip") else return assert false;
                assert Encoding.get_chunks_size(encoding) == 1;
                assert Encoding.get_chunk(fs, encoding, 0) == ?"logo-image";

              },
            );

            test(
              "Merge another file system into the current file system",
              func() {
                let fs2 = FileSystem.new(region);

                let asset_1 = Asset.new();
                asset_1.content_type := "image/png";
                asset_1.is_aliased := ?false;
                asset_1.max_age := ?8900;
                asset_1.allow_raw_access := ?true;
                ignore Asset.create_encoding(fs, asset_1, "gzip", "content" : Blob, "sha256" : Blob);

                let #ok(_) = FileSystem.insert_asset(fs2, "/assets/images/logo.png", asset_1);

                let asset_2 = Asset.new();
                asset_2.content_type := "video/mp4";
                asset_2.is_aliased := ?true;
                asset_2.max_age := ?12232;
                asset_2.allow_raw_access := ?false;
                ignore Asset.create_encoding(fs, asset_2, "br", "brotli-encoded" : Blob, "sha256" : Blob);

                let #ok(_) = FileSystem.insert_asset(fs2, "/assets/videos/sonic.mp4", asset_2);

                FileSystem.merge(fs, fs2);

                let #ok(?(logo)) = FileSystem.get_asset(fs, "/assets/images/logo.png") else return assert false;

                assert logo.content_type == "image/png";
                assert logo.is_aliased == ?false;
                assert logo.max_age == ?8900;
                assert logo.allow_raw_access == ?true;
                let ?encoding_1 = Asset.get_encoding(fs, logo, "gzip") else return assert false;
                assert Encoding.get_chunks_size(encoding_1) == 1;
                assert Encoding.get_chunk(fs, encoding_1, 0) == ?("content" : Blob);

                let #ok(?(sonic)) = FileSystem.get_asset(fs, "/assets/videos/sonic.mp4") else return assert false;

                assert sonic.content_type == "video/mp4";
                assert sonic.is_aliased == ?true;
                assert sonic.max_age == ?12232;
                assert sonic.allow_raw_access == ?false;

                let ?encoding_2 = Asset.get_encoding(fs, sonic, "br") else return assert false;
                assert Encoding.get_chunks_size(encoding_2) == 1;
                assert Encoding.get_chunk(fs, encoding_2, 0) == ?("brotli-encoded" : Blob);

              },
            );

          },
        );

        test(
          "clear file system",
          func() {
            assert MemoryRegion.allocated(region) > 0;

            FileSystem.clear(fs);

            let assets = FileSystem.to_array(fs);
            assert assets.size() == 0;

            assert MemoryRegion.allocated(region) == 0;

          },
        );

      },
    )

  };
};
