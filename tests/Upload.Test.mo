import Blob "mo:base/Blob";
import Time "mo:base/Time";

import { test; suite } "mo:test";
import Sha256 "mo:sha2/Sha256";
import Vector "mo:vector";
import Map "mo:map/Map";
import MemoryRegion "mo:memory-region/MemoryRegion";

import Upload "../src/BaseAssets/Upload";

actor {
  let region = MemoryRegion.new();
  let upload = Upload.new(region);

  var curr_time = Time.now();
  let one_second = 1000 * 1000;
  let expire_duration = one_second;

  func verify_content(chunk_id : Nat, content : Blob) : Bool {
    let ?(chunk) = Upload.get_chunk(upload, chunk_id) else return false;
    return MemoryRegion.loadBlob(region, chunk.pointer.0, chunk.pointer.1) == content;
  };

  public func runTests() {
    suite(
      "Upload test",
      func() {

        test(
          "upload chunks",
          func() {
            let #ok({ batch_id }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
            let #ok({ chunk_id }) = Upload.create_chunk(upload, { batch_id; content = ("Hello world chunk 👋" : Blob) }, curr_time, 1000) else return assert false;

            let ?(chunk) = Upload.get_chunk(upload, chunk_id) else return assert false;
            assert chunk.batch_id == batch_id;
            assert MemoryRegion.loadBlob(region, chunk.pointer.0, chunk.pointer.1) == "Hello world chunk 👋";

            let #ok({ chunk_id = chunk_id2 }) = Upload.create_chunk(upload, { batch_id; content = ("Another chunk" : Blob) }, curr_time, 1000) else return assert false;

            let ?(chunk2) = Upload.get_chunk(upload, chunk_id2) else return assert false;
            assert chunk2.batch_id == batch_id;
            assert MemoryRegion.loadBlob(region, chunk2.pointer.0, chunk2.pointer.1) == "Another chunk";

          },
        );

        test(
          "set configuration",
          func() {
            Upload.set_max_batches(upload, ??2);
            assert upload.configuration.max_batches == ?2;

            Upload.set_max_chunks(upload, ??4);
            assert upload.configuration.max_chunks == ?4;

            Upload.set_max_bytes(upload, ??40);
            assert upload.configuration.max_bytes == ?40;

          },
        );

        suite(
          "test configuration limits",
          func() {

            let #ok({ batch_id }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;

            test(
              "try storing more than max bytes (40)",
              func() {
                let #ok({ chunk_id }) = Upload.create_chunk(upload, { batch_id; content = ("The third chunk globally" : Blob) }, curr_time, expire_duration) else return assert false;
                assert verify_content(chunk_id, "The third chunk globally");

                let #err(_) = Upload.create_chunk(upload, { batch_id; content = ("greater than 40 bytes in total" : Blob) }, curr_time, expire_duration) else return assert false;

                assert Map.size(upload.chunks) == 3;

                let #ok({ chunk_id = chunk_id3 }) = Upload.create_chunk(upload, { batch_id; content = ("<40" : Blob) }, curr_time, expire_duration) else return assert false;
                assert verify_content(chunk_id3, "<40");
                assert Map.size(upload.chunks) == 4;
              },
            );

            test(
              "try creating more than max chunks (4)",
              func() {

                let #err(_) = Upload.create_chunk(upload, { batch_id; content = ("The 5th chunk globally" : Blob) }, curr_time, expire_duration) else return assert false;
                assert Map.size(upload.chunks) == 4;

              },
            );

            test(
              "try creating more than max batches (2)",
              func() {
                let #err(_) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
                assert Map.size(upload.batches) == 2;
              },
            );
          },
        );

        test(
          "update configuration",
          func() {
            Upload.set_max_batches(upload, ??123);
            Upload.set_max_chunks(upload, ??4321);
            Upload.set_max_bytes(upload, ?null); // no limit

            assert upload.configuration.max_batches == ?123;
            assert upload.configuration.max_chunks == ?4321;
            assert upload.configuration.max_bytes == null;

          },
        );

        test(
          "no config updates are made if the update value is null",
          func() {

            // no updates are made if the update value is null
            Upload.set_max_batches(upload, null);
            Upload.set_max_chunks(upload, null);
            Upload.set_max_bytes(upload, null);

            assert upload.configuration.max_batches == ?123;
            assert upload.configuration.max_chunks == ?4321;
            assert upload.configuration.max_bytes == null;

          },
        );

        var rogue_batch_id = 0;

        test(
          "test batch expiration",
          func() {
            curr_time += expire_duration + 1;

            let batch_num = Map.size(upload.batches);

            assert batch_num > 1;

            // previous batches expire when the current time has exceeded the expiration duration
            let #ok({ batch_id }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
            let #ok(_) = Upload.create_chunk(upload, { batch_id; content = ("Hello world chunk 👋" : Blob) }, curr_time, expire_duration) else return assert false;

            assert Map.size(upload.batches) != batch_num;
            assert Map.size(upload.batches) == 1;

            rogue_batch_id := batch_id;

          },
        );

        test(
          "test batch removal",
          func() {
            let #ok({ batch_id }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
            assert Map.size(upload.batches) == 2;

            let ?batch = Map.get(upload.batches, Map.nhash, batch_id) else return assert false;
            assert Vector.size(batch.chunk_ids) == 0;

            let #ok({ chunk_id }) = Upload.create_chunk(upload, { batch_id; content = ("Hello world chunk 👋" : Blob) }, curr_time, expire_duration) else return assert false;
            let chunk = Upload.get_chunk(upload, chunk_id);
            assert verify_content(chunk_id, "Hello world chunk 👋");
            assert Vector.toArray(batch.chunk_ids) == [chunk_id];

            let #ok({ chunk_id = chunk_id2 }) = Upload.create_chunk(upload, { batch_id; content = ("Chunk number 2" : Blob) }, curr_time, expire_duration) else return assert false;
            let ?chunk2 = Upload.get_chunk(upload, chunk_id2) else return assert false;
            assert verify_content(chunk_id2, "Chunk number 2");
            assert Vector.toArray(batch.chunk_ids) == [chunk_id, chunk_id2];

            let ?removed_batch = Upload.remove_batch(upload, batch_id);
            assert Vector.toArray(removed_batch.chunk_ids) == [chunk_id, chunk_id2];

            assert not verify_content(chunk_id, "Hello world chunk 👋");
            assert not verify_content(chunk_id2, "Chunk number 2");

          },
        );

        test(
          "check for memory leaks after last batch is removed",
          func() {
            assert MemoryRegion.allocated(region) > 0;

            let ?_ = Upload.remove_batch(upload, rogue_batch_id);

            assert MemoryRegion.allocated(region) == 0;
          },
        );

        test(
          "clear all batches",
          func() {
            let #ok({ batch_id }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
            let #ok({ chunk_id }) = Upload.create_chunk(upload, { batch_id; content = ("Hello world chunk 👋" : Blob) }, curr_time, expire_duration) else return assert false;

            let #ok({ batch_id = batch_id2 }) = Upload.create_batch(upload, curr_time, expire_duration) else return assert false;
            let #ok({ chunk_id = chunk_id2 }) = Upload.create_chunk(upload, { batch_id; content = ("Another chunk" : Blob) }, curr_time, expire_duration) else return assert false;

            assert Map.size(upload.batches) == 2;
            assert Map.size(upload.chunks) == 2;
            assert MemoryRegion.allocated(region) > 0;

            Upload.clear(upload);

            assert Map.size(upload.batches) == 0;
            assert Map.size(upload.chunks) == 0;
            assert MemoryRegion.allocated(region) == 0;
          },
        );

        test("propose commit batch", func() {});

      },
    );
  };
};
