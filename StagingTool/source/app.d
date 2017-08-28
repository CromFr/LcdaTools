import std.stdio;
import std.array: join;
import std.string;
import std.conv;
import std.path;
import std.file;
import std.file: readFile = read, writeFile = write;
import std.exception;


void info(T...)(T args){
	stderr.writeln("\x1b[32;1m", args, "\x1b[m");
}
void warning(T...)(T args){
	stderr.writeln("\x1b[33;1mWarning: ", args, "\x1b[m");
}
void error(T...)(T args){
	stderr.writeln("\x1b[31;40;1mError: ", args, "\x1b[m");
}

bool verbose = false;

int main(string[] args)
{

	import std.getopt;
	string xmlPath = null;
	bool force = false;

	auto res = getopt(args, config.passThrough,
		"o|xml-out", "Path to moduledownloaderresources.xml. If existing, will read it to only generate modified client files. '-' to print to stdout.", &xmlPath,
		"f|force", "Generate all client files even if they have not been modified", &force,
		"verbose|v","Print all file operations", &verbose,
		);
	if(res.helpWanted || args.length < 3){
		defaultGetoptPrinter(
			"Scan resource directories to find .hak, .tlk, .bmu, .trx files and generate client files to output_folder\n"
			~args[0]~" output_folder resource_folder1 [resource_folder2 ...]",
			res.options);
		return 0;
	}

	auto outPath = DirEntry(args[1]);
	auto resPaths = args[2 .. $];


	if(xmlPath is null){
		xmlPath = buildPath(outPath, "moduledownloaderresources.xml");
	}

	//Load existing xml hashes
	string[string] resourceHashes;
	if(xmlPath != "-" && xmlPath.exists){
		import std.xml;
		auto parser = new DocumentParser(xmlPath.readText);
		parser.onStartTag["resource"] = (ElementParser xml){
			resourceHashes[xml.tag.attr["name"].toLower] = xml.tag.attr["hash"];
		};
		parser.parse();
	}

	//Generate resource list
	Resource[] resources;

	foreach(resPath ; resPaths){
		foreach(file ; resPath.dirEntries(SpanMode.shallow)){

			auto extension = file.name.extension.toLower;
			switch(extension){
				case ".trx":
				case ".hak":
				case ".bmu":
				case ".tlk":
					if(verbose) writeln("- ", file.name);

					auto expectedHash = file.baseName.toLower in resourceHashes;
					auto resource = Resource(file, expectedHash is null? null : *expectedHash, outPath, force);
					if(expectedHash !is null)
						resourceHashes.remove(resource.name.toLower);
					resources ~= resource;
					break;
				default:
					break;
			}
		}
	}

	foreach(name, hash ; resourceHashes){
		warning("Removed file: ", name);
	}

	//Sort resource list
	import std.algorithm.sorting: multiSort;
	resources.multiSort!("a.type < b.type", "a.name < b.name");


	//Generate XML
	string xml = `<?xml version="1.0" encoding="utf-8"?>`~"\n";
	xml ~= `<content xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">` ~ "\n";
	foreach(const ref resource ; resources){
		xml ~= "  " ~ resource.toXml(`<server-ref><string>0</string><string>1</string></server-ref>`) ~ "\n";
	}
	xml ~= `</content>` ~ "\n";

	//Write XML
	if(xmlPath == "-")
		writeln(xml);
	else
		xmlPath.writeFile(xml);
	return 0;

}


struct Resource{
	this(in DirEntry resFile, in string expectedResHash, in DirEntry outputDir, bool force){
		name = resFile.name.baseName;
		switch(name.extension.toLower){
			case ".trx": type = ResType.DirectoryEntry; break;
			case ".hak": type = ResType.Hak; break;
			case ".bmu": type = ResType.Music; break;
			case ".tlk": type = ResType.Tlk; break;
			default: assert(0, "Unknown resource extension");
		}

		bool genDlFile = false;

		import std.digest.sha;
		immutable data = cast(immutable ubyte[])readFile(resFile);
		resSize = data.length;
		resHash = data.sha1Of.toHexString.idup;


		auto dlFilePath = buildPath(outputDir, name~".lzma");


		if(expectedResHash is null){
			genDlFile = true;
			info("New file: '", name, "' ('", resFile.name, "')");
		}
		else if(resHash != expectedResHash){
			genDlFile = true;
			info("Modified file: ", name, "' ('", resFile.name, "')");
		}
		else if(!dlFilePath.exists){
			genDlFile = true;
		}

		ubyte[] dlData;
		if(genDlFile){
			import std.process: execute, Config;
			auto command = ["lzma", "-zc", "--threads=0", resFile.name];

			if(verbose) writeln("Compressing ", name, ": ", command.join(" "));
			auto res = execute(command,
				null,
				Config.none,
				size_t.max,
				outputDir);
			enforce(res.status == 0, "lzma command failed:\n"~res.output);

			dlData = cast(ubyte[])res.output.dup();
			writeFile(dlFilePath, dlData);
		}
		else{
			dlData = cast(ubyte[])readFile(dlFilePath);
		}

		dlSize = dlData.length;
		dlHash = dlData.sha1Of.toHexString.idup;
	}

	string name;
	ResType type;
	string resHash;
	size_t resSize;
	string dlHash;
	size_t dlSize;

	string toXml(in string serverList) const{
		return "<resource "
				~" name="~("\""~name~"\"").leftJustify(32+2)
				~" type="~("\""~type.to!string~"\"").leftJustify(14+2)
				~" hash=\""~resHash~"\""
				~" size="~("\""~resSize.to!string~"\"").leftJustify(9+2)
				~" downloadHash=\""~dlHash~"\""
				~" dlsize=\""~dlSize.to!string~"\""
				~" dlsize="~("\""~dlSize.to!string~"\"").leftJustify(9+2)
				~" critical=\"false\""
				~" exclude=\"false\""
				~" urlOverride=\"\""
				~">"~serverList~"</resource>";
	}


	enum ResType{
		Hak,
		Tlk,
		Music,
		DirectoryEntry,
	}
}