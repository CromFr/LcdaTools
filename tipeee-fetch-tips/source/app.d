import std;
import vibe.d;
import html;
import mysql;

struct Tip {
	uint id;
	string login;
	string nick;
	string mail;
	Date date;
	string firstName;
	string lastName;
	int amount;
	enum Frequency { unique, monthly }
	Frequency freq;
	string comment;
}

Tip[] getMonthTips(string pageName, int pageID, string accessToken, int year, int month){
	if(month + 1 == 13){
		year += 1;
		month = 1;
	}
	else{
		month += 1;
	}
	auto dt = DateTime(year, month, 1);
	dt -= seconds(1);

	Tip[] ret;

	auto url = format!"https://fr.tipeee.com/%s/dashboard/tippers-file/%d-PER_MONTH-%04d%02d%02d%02d%02d%02d/detail"(pageName, pageID, dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
	requestHTTP(url,
			(scope req) {
				req.method = HTTPMethod.GET;
				req.headers.addField("Cookie", `auth={"access_token":"`~accessToken~`"}`);
			},
			(scope res) {
				if(res.statusCode != 200){
					if(res.statusCode == 404)
						throw new Exception("not found");
					throw new Exception(format!"Request returned %s"(res));
				}
				auto data = res.bodyReader.readAllUTF8();
				//writefln("data: %s", data);
				auto html = createDocument(data);
				auto tr = html.root.firstChild;

				while(tr !is null){
					if(tr.tag == "tr"){
						int i = 0;
						Tip tip;

						tip.id = tr.id.split("-")[1].to!uint;

						auto td = tr.firstChild;
						while(td !is null){
							if(td.tag == "td"){
								switch(i++){
									case 0: // checkbox
										break;
									case 1: // login
										tip.login = td.text.strip().idup();
										break;
									case 2: // nickname
										tip.nick = td.text.strip().idup();
										break;
									case 3: // mail
										tip.mail = td.text.strip().idup();
										break;
									case 4: // amount
										auto amount = td.text.strip().idup();
										tip.amount = amount.split(" ")[0].to!int;
										break;
									case 5: // date
										auto dateSplit = td.text.strip().idup().split(" ");
										tip.date.day = dateSplit[0].to!int;
										switch(dateSplit[1].toLower){
											case "janv.": tip.date.month = cast(Month)1; break;
											case "févr.": tip.date.month = cast(Month)2; break;
											case "mars":  tip.date.month = cast(Month)3; break;
											case "avr.":  tip.date.month = cast(Month)4; break;
											case "mai":   tip.date.month = cast(Month)5; break;
											case "juin":  tip.date.month = cast(Month)6; break;
											case "juil.": tip.date.month = cast(Month)7; break;
											case "août":  tip.date.month = cast(Month)8; break;
											case "sept.": tip.date.month = cast(Month)9; break;
											case "oct.":  tip.date.month = cast(Month)10; break;
											case "nov.":  tip.date.month = cast(Month)11; break;
											case "déc.":  tip.date.month = cast(Month)12; break;
											default:
												tip.date.month = cast(Month)1;
												stderr.writefln("Warning: unknown month '%s'", dateSplit[1]);
										}
										tip.date.year = dateSplit[2].to!int;

										break;
									case 6: // frequency
										switch(td.text.strip()){
											case "tip unique": tip.freq = Tip.Frequency.unique; break;
											case "par mois":   tip.freq = Tip.Frequency.monthly; break;
											default: break;
										}
										break;
									case 7: // comment
										auto comment = td.text.strip().idup();
										if(comment != "-")
											tip.comment = comment;
										break;
									case 8: // first name
										tip.firstName = td.text.strip().idup();
										break;
									case 9: // last name
										tip.lastName = td.text.strip().idup();
										break;
									default: break;
								}
							}
							td = td.nextSibling();
						}
						writeln("  ", tip);
						ret ~= tip;
					}
					tr = tr.nextSibling();
				}
			}
		);
	return ret;
}


void main(string[] args)
{
	string mysqlConnStr = "host=localhost;port=3306;user=nwnx;pwd=123;db=nwnx";
	string tipeeeToken;
	int tipeeeID = 148671;
	string tipeeeName = "la-colere-d-aurile";
	bool fetchAll = false;
	auto helpInformation = getopt(
		args,
		config.required, "token", "Tipeee auth token / cookie ", &tipeeeToken,
		"proj-id", "Tipeee project ID", &tipeeeID,
		"proj-name", "Tipeee project name", &tipeeeName,
		"sql", "MySQL connection string. Ex: " ~ mysqlConnStr, &mysqlConnStr,
		"all", "Fetch all tips since 2017.10.1", &fetchAll,
	);

	if (helpInformation.helpWanted)
	{
		defaultGetoptPrinter("Some information about the program.", helpInformation.options);
		return;
	}

	// Connect MySQL
	Connection conn = new Connection(mysqlConnStr);
	scope(exit) conn.close();
	conn.exec("
		CREATE TABLE IF NOT EXISTS `tipeee_tips` (
		  `transaction_id` INT NOT NULL,
		  `transaction_date` DATE NOT NULL,
		  `transaction_monthly` VARCHAR(8) NOT NULL,
		  `tip_date` VARCHAR(45) NOT NULL,
		  `tipper_id` VARCHAR(45) NULL,
		  `tipper_pseudo` VARCHAR(45) NULL,
		  `amount` INT NULL,
		  `comment` MEDIUMTEXT NULL,
		  PRIMARY KEY (`transaction_id`, `transaction_date`, `transaction_monthly`, `tip_date`))
		ENGINE = InnoDB
		DEFAULT CHARACTER SET = utf8;
	");

	void insertTip(int year, int month, in Tip tip){
		conn.exec(
			"INSERT IGNORE INTO tipeee_tips
			(`transaction_id`,`transaction_date`,`transaction_monthly`,`tip_date`,`tipper_id`,`tipper_pseudo`,`amount`,`comment`)
			VALUES(?,?,?,?,?,?,?,?)",
			tip.id, tip.date, tip.freq.to!string, Date(year, month, 1), tip.login, tip.nick, tip.amount, tip.comment,
		);
	}

	// Fetch tips
	auto now = Clock.currTime();
	if(!fetchAll) {
		auto tips = getMonthTips(tipeeeName, tipeeeID, tipeeeToken, now.year, now.month);

		foreach(tip ; tips){
			insertTip(now.year, now.month, tip);
		}
	}
	else {
		try {
			int year = now.year;
			int month = now.month;
			while(true){
				writefln("%04d-%02d", year, month);
				auto tips = getMonthTips(tipeeeName, tipeeeID, tipeeeToken, year, month);
				foreach(tip ; tips){
					insertTip(year, month, tip);
				}

				month--;
				if(month == 0){
					month = 12;
					year--;
				}
			}
		}
		catch(Exception e){
			if(e.msg != "not found"){
				throw e;
			}
		}
	}
}
