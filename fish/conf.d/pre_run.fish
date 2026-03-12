function pre_run --on-event fish_preexec
    set -g MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT "$argv"
    title "$MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT"
end
