import std.stdio: writef, writefln;
import std.file: exists, read, write;
import std.path: expandTilde;
import std.process: execute;
import std.regex: ctRegex, matchFirst;
import std.json;

const auto regSock = ctRegex!"SSH_AUTH_SOCK=([A-Za-z\\-\\.0-9/]+);";
const auto regPid = ctRegex!"SSH_AGENT_PID=([0-9]+);";

const auto config = "~/.alien-agent.json";

enum Color {
  Black,
  Red,
  Green,
  Yellow,
  Blue,
  Magenta,
  Cyan,
  White
}

int main() {
  const auto expandedConfig = config.expandTilde;

  bool needStart = true;

  if(expandedConfig.exists) {
    try {
      auto saved = (cast(string)expandedConfig.read).parseJSON;
      if("pid" in saved &&
         saved["pid"].type == JSONType.string &&
         "sock" in saved &&
         saved["sock"].type == JSONType.string) {
        if(exists("/proc/" ~ saved["pid"].str)) {
          printExports(saved["pid"].str, saved["sock"].str);
          needStart = false;
        }
      } else {
        printError("Broken config");
      }
    } catch(JSONException) {
      printError("Broken config");
    }
  }

  if(needStart) {
    auto res = execute(["ssh-agent"]);
    if(res.status != 0) {
      printError("Cannot start ssh-agent!");
      return 1;
    }

    auto sock = matchFirst(res.output, regSock)[1];
    auto pid = matchFirst(res.output, regPid)[1];

    printOk("Ssh-agent started!");

    auto json = JSONValue(["pid": pid, "sock": sock]);
    expandedConfig.write(json.toJSON);
    printExports(pid, sock);
  } else {
    printOk("Ssh-agent already started");
  }

  return 0;
}

void printExports(string pid, string sock) {
  writef!(
    "SSH_AGENT_PID=%s;" ~
    "export SSH_AGENT_PID;" ~
    "SSH_AUTH_SOCK=%s;" ~
    "export SSH_AUTH_SOCK;"
    )(pid, sock);
}

void printMessage(string status, string msg, Color color = Color.White) {
  writefln!(
    "echo -e " ~
    "\"\\033[3%dm" ~
    "[%s] %s" ~
    "\\033[0m\";"
    )(color, status, msg);
}

void printError(string msg) {
  printMessage("ERROR", msg, Color.Red);
}

void printOk(string msg) {
  printMessage("OK", msg, Color.Green);
}
