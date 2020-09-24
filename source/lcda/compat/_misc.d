module lcda.compat._misc;

import std.stdio;
import std.exception;
import nwn.nwscript;



void SignalBug(NWString sMessage)
{
	stderr.writeln("\x1b[1;31mERROR: " ~ sMessage ~ "\x1b[m");
}

void Enforce(NWInt result, NWString msg, NWString file, NWInt line){
	if(!result){
		SignalBug(file ~ ":" ~ IntToString(line) ~ ": Enforce failed: " ~ msg);
	}
}
