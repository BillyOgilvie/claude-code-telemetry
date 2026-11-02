# Source this from ~/.bashrc or ~/.zshrc. Adds `cct`, which starts Claude Code with tags for the dashboards.
#
#   cct myapp fix-login 2          project task run
#   cct myapp fix-login            run defaults to 1
#   cct                            project = git repo or folder name, task = untagged, run = 1
#   cct myapp fix-login 2 -- --resume    anything after -- goes to claude
#
# Plain `claude` is untouched. Tag values keep only A-Z a-z 0-9 . _ -
# Argument parsing tested in bash; zsh and macOS should work but are untested.
_cct_clean() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'; }
cct() {
  local project task run
  [ $# -gt 0 ] && [ "${1#-}" = "$1" ] && { project=$1; shift; }
  [ $# -gt 0 ] && [ "${1#-}" = "$1" ] && { task=$1; shift; }
  [ $# -gt 0 ] && [ "${1#-}" = "$1" ] && { run=$1; shift; }
  [ "$1" = "--" ] && shift
  project=${project:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}
  OTEL_RESOURCE_ATTRIBUTES="project=$(_cct_clean "$project"),task=$(_cct_clean "${task:-untagged}"),run=$(_cct_clean "${run:-1}")" \
    command claude "$@"
}
