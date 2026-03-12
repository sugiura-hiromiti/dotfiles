function post_run --on-event fish_postexec
    set -l last_exit_code $status
    if test $last_exit_code -ne 0
        ntfy "`$MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT` has failed" "with exit code: $last_exit_code"
    end
    set -g MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT "$PWD"
    title "$MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT"
end
