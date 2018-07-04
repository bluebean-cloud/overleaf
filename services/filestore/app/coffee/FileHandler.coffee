settings = require("settings-sharelatex")
PersistorManager = require("./PersistorManager")
LocalFileWriter = require("./LocalFileWriter")
logger = require("logger-sharelatex")
FileConverter = require("./FileConverter")
KeyBuilder = require("./KeyBuilder")
async = require("async")
ImageOptimiser = require("./ImageOptimiser")

module.exports = FileHandler =

	insertFile: (bucket, key, stream, callback)->
		convertedKey = KeyBuilder.getConvertedFolderKey key
		PersistorManager.deleteDirectory bucket, convertedKey, (error) ->
			return callback(error) if error?
			PersistorManager.sendStream bucket, key, stream, callback

	deleteFile: (bucket, key, callback)->
		convertedKey = KeyBuilder.getConvertedFolderKey key
		async.parallel [
			(done)-> PersistorManager.deleteFile bucket, key, done
			(done)-> PersistorManager.deleteDirectory bucket, convertedKey, done
		], callback

	getFile: (bucket, key, opts = {}, callback)->
		# In this call, opts can contain credentials
		logger.log bucket:bucket, key:key, opts:@_scrubSecrets(opts), "getting file"
		if !opts.format? and !opts.style?
			@_getStandardFile bucket, key, opts, callback
		else
			@_getConvertedFile bucket, key, opts, callback

	_getStandardFile: (bucket, key, opts, callback)->
		PersistorManager.getFileStream bucket, key, opts, (err, fileStream)->
			if err?
				logger.err  bucket:bucket, key:key, opts:FileHandler._scrubSecrets(opts), "error getting fileStream"
			callback err, fileStream

	_getConvertedFile: (bucket, key, opts, callback)->
		convertedKey = KeyBuilder.addCachingToKey key, opts
		PersistorManager.checkIfFileExists bucket, convertedKey, (err, exists)=>
			if err?
				return callback err
			if exists
				PersistorManager.getFileStream bucket, convertedKey, opts, callback
			else
				@_getConvertedFileAndCache bucket, key, convertedKey, opts, callback

	_getConvertedFileAndCache: (bucket, key, convertedKey, opts, callback)->
		convertedFsPath = ""
		originalFsPath = ""
		async.series [
			(cb) =>
				@_convertFile bucket, key, opts, (err, fileSystemPath, originalFsPath) ->
					convertedFsPath = fileSystemPath
					originalFsPath = originalFsPath
					cb err
			(cb)->
				ImageOptimiser.compressPng convertedFsPath, cb
			(cb)->
				PersistorManager.sendFile bucket, convertedKey, convertedFsPath, cb
		], (err)->
			if err?
				LocalFileWriter.deleteFile convertedFsPath, ->
				LocalFileWriter.deleteFile originalFsPath, ->
				return callback(err)
			PersistorManager.getFileStream bucket, convertedKey, opts, callback

	_convertFile: (bucket, originalKey, opts, callback)->
		@_writeS3FileToDisk bucket, originalKey, opts, (err, originalFsPath)->
			if err?
				return callback(err)
			done = (err, destPath)->
				if err?
					logger.err err:err, bucket:bucket, originalKey:originalKey, opts:FileHandler._scrubSecrets(opts), "error converting file"
					return callback(err)
				LocalFileWriter.deleteFile originalFsPath, ->
				callback(err, destPath, originalFsPath)

			if opts.format?
				FileConverter.convert originalFsPath, opts.format, done
			else if opts.style == "thumbnail"
				FileConverter.thumbnail originalFsPath, done
			else if opts.style == "preview"
				FileConverter.preview originalFsPath, done
			else
				return callback(new Error("should have specified opts to convert file with #{JSON.stringify(opts)}"))


	_writeS3FileToDisk: (bucket, key, opts, callback)->
		PersistorManager.getFileStream bucket, key, opts, (err, fileStream)->
			if err?
				return callback(err)
			LocalFileWriter.writeStream fileStream, key, callback

	getDirectorySize: (bucket, project_id, callback)->
		logger.log bucket:bucket, project_id:project_id, "getting project size"
		PersistorManager.directorySize bucket, project_id, (err, size)->
			if err?
				logger.err  bucket:bucket, project_id:project_id, "error getting size"
			callback err, size

	_scrubSecrets: (opts)->
		safe = Object.assign {}, opts
		delete safe.credentials
		safe
