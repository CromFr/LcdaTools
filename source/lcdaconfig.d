module lcdaconfig;
import std.json;
import std.getopt;
import std.conv;
import std.exception: enforce;

class LcdaConfig{
static:
	GetoptResult init(ref string[] args){

		string configPath;
		string[string] configOverride;

		auto res = getopt(args, config.passThrough,
			"config|c","LCDA config file to use\nDefault: ./config.json or ../config.json (whichever exists)", &configPath,
			"configovr","Override a value in config\nSyntax is `--configovr foo=key`\nCan be specified multiple times", &configOverride,
			);
		res.options = res.options[0..$-1];//remove help option
		if(res.helpWanted)
			args ~= "--help";


		import std.file: readText;

		if(configPath is null){
			import std.path: exists;
			if("./config.json".exists)
				configPath = "./config.json";
			else if("../config.json".exists)
				configPath = "../config.json";
			else
				throw new Exception("Could not find config.json");
		}
		auto json = parseJSON(configPath.readText);

		foreach(string key, ref value ; json){
			if(value.type == JSON_TYPE.OBJECT || value.type == JSON_TYPE.ARRAY){
				complexValues[key] = value;
			}
			else{
				enforce(value.type == JSON_TYPE.STRING, "Values in config files must be objects, arrays or strings");
				values[key] = value.str;
			}
		}

		foreach(ref key, ref value ; configOverride){
			values[key] = value;
		}

		return res;
	}

	alias values this;
	string[string] values;
	JSONValue[string] complexValues;
}


void improvedGetoptPrinter(string text, Option[] opt){
	import std.stdio: writef, writeln;
	import std.string: wrap, leftJustify, splitLines;
	import std.algorithm: map, reduce;

	size_t widthOptLong;
	bool hasRequiredOpt = false;
	size_t widthHelpIndentation;
	foreach(ref o ; opt){
		if(o.optLong.length > widthOptLong)
			widthOptLong = o.optLong.length;
		if(o.required)
			hasRequiredOpt = true;
	}
	widthHelpIndentation = widthOptLong + 8;
	auto helpIndent = "".leftJustify(widthHelpIndentation);

	writeln(text);
	writeln();
	if(helpIndent) writeln("Options with * are required");

	foreach(ref o ; opt){
		writef(" %s %s %*s  ",
			o.required? "*" : " ",
			o.optShort !is null? o.optShort : "  ",
			widthOptLong, o.optLong );

		auto wrappedText = o.help
			.splitLines
			.map!(a=>a.wrap(80-widthHelpIndentation).splitLines)
			.reduce!(delegate(a, b){return a~b;});

		bool first = true;
		foreach(l ; wrappedText){
			writeln(first? "" : helpIndent, l);
			first = false;
		}
		writeln();
	}
}