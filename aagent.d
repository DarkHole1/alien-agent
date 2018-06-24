import std.stdio: writef;
import std.file: exists, read, write;
import std.path: expandTilde;
import std.process: execute, environment;
import std.regex: ctRegex, matchFirst;
import std.json: parseJSON, toJSON, JSONValue;

const auto regSock = ctRegex!"SSH_AUTH_SOCK=([A-Za-z\\-\\.0-9/]+);";
const auto regPid = ctRegex!"SSH_AGENT_PID=([0-9]+);";

const auto configFile = "~/.alien-agent.json";

int main() {
  bool needStart = true;

  if(configFile.expandTilde.exists) {
    try {
      auto saved = (cast(string)configFile.expandTilde.read).parseJSON;
      if("pid" in saved && "sock" in saved && exists("/proc/" ~ saved["pid"].str)) {
        printExports(saved["pid"].str, saved["sock"].str);
        needStart = false;
      }
    } catch(Throwable) { }
  }

  if(needStart) {
    auto res = execute(["ssh-agent"]);
    if(res.status != 0) return 1;

    auto sock = matchFirst(res.output, regSock)[1];
    auto pid = matchFirst(res.output, regPid)[1];

    auto json = JSONValue(["pid": pid, "sock": sock]);
    configFile.expandTilde.write(toJSON(json));
    printExports(pid, sock);
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
