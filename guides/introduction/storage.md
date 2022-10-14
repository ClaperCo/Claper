# Presentation storage

You can configure different storage options for your presentations. By default, Claper uses the local storage.

Each presentation has a unique hash that is generated in two steps, first with `:erlang.phash2("#{code}-#{name}")` and then `:erlang.phash2("#{hash}-#{System.system_time(:second)}")`.

## Local storage

The local storage is the default storage option. It stores the presentations in the `priv/static/uploads/[hash]` folder.

## S3 storage

You can use S3 storage to store your presentations.

When user upload a new presentation, the destination file is uploaded to S3 in your bucket in `presentations/[hash]` and the local file is deleted.
