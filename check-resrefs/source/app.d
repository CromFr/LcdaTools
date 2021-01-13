import std;
import nwn.fastgff;


int main(string[] args)
{
	shared bool errored = false;
	enum isCharAllowed = "(a >= 0x30 && a <= 0x39) || (a >= 0x61 && a <= 0x7a) || a == '_'";

	size_t parsedFilesCount;

	foreach(file ; parallel(args[1].dirEntries("*.uti", SpanMode.shallow))){
		parsedFilesCount++;

		try{
			auto resName = file.baseName.stripExtension;
			auto resRef = new FastGff(file)["TemplateResRef"].to!string;

			if(resName != resRef){
				synchronized stderr.writefln("Error in %36s: Mismatch between resname='%s' and resref='%s'",
					file.baseName, resName, resRef
				);
				errored = true;
			}

			if(!resRef.toLower.all!isCharAllowed){
				synchronized stderr.writefln("Error in %36s: Forbidden character used in resref='%s'",
					file.baseName, resRef, resRef.toLower.find!isCharAllowed[0]
				);
				errored = true;
			}
		}
		catch(UTFException){
			synchronized stderr.writefln("Error in %36s: Non UTF8 character in resref value",
				file.baseName
			);
			errored = true;
		}
	}

	writefln("%d items were checked", parsedFilesCount);
	return errored;
}
// []{}()éèêàâùô'"\/+=-:!$#%
// abcdefghijklmnopqrstuvwxyz_