# tracker_automations

Automations that manage the **Moodle tracker (Jira) integration queues**. Each
subdirectory is one job that a scheduler (Jenkins) runs on a cadence to move issues
between queues, apply labels/priorities, comment, close tested issues, and gather
integration-cycle statistics.

> **⚠️ These scripts mutate live Jira.** They transition issues, edit custom fields, post
> comments on the configured `jiraserver`, and some launch Jenkins jobs. A run against
> the real tracker is production impact. Most jobs accept a `quiet` (set to anything other
> than `false` to suppress tracker writes) or `dryrun`/`debug` option — use it, and prefer
> a test tracker. See [AGENTS.md](../AGENTS.md#safety-read-before-running-anything).

## Shared configuration: `jira.sh`

Every automation sources the repo-root [`jira.sh`](../jira.sh):

```bash
source "${mydir}/../../jira.sh"
```

`jira.sh` centralises:
- **Custom-field display names** (`customfield_integrator`, `customfield_tester`,
  `customfield_currentlyInIntegration`, `customfield_integrationPriority`, …).
- **Saved filter names** used in JQL (`filter_candidatesForIntegration`,
  `filter_mustFixIssues`, …).
- Validation of the required connection vars (`jiraclicmd`, `jiraserver`, `jirauser`,
  `jirapass`) and construction of `$basereq` — the base Jira CLI invocation every script
  builds its commands on.

Numeric custom-field ids and other environment-specific values are passed per-job via
environment variables (see each subdirectory's `README.md`).

## Common environment variables

| Variable | Meaning |
|----------|---------|
| `jiraclicmd` | Path/command to invoke the Jira CLI. |
| `jiraserver` | Jira server URL. |
| `jirauser` / `jirapass` | Credentials for the automation user. |
| `WORKSPACE` | Job working dir; results/logs (`*.csv`, `*.log`) are written here. |
| `quiet` / `dryrun` | Suppress write operations (where supported). |

## Jobs

| Subdirectory | Purpose |
|--------------|---------|
| [`continuous_manage_queues`](continuous_manage_queues/) | Manage candidates/current queues during continuous integration. |
| [`normal_manage_queues`](normal_manage_queues/) | Manage the queues during normal periods. |
| [`move_to_current_integration`](move_to_current_integration/) | Move awaiting issues into current integration. |
| [`mv_reopened_out_from_current`](mv_reopened_out_from_current/) | Move reopened issues out of current. |
| [`component_leads_integration_mover`](component_leads_integration_mover/) | Route undecided issues to CLR vs IR. |
| [`close_tested_issues`](close_tested_issues/) | Close tested/fixed issues. |
| [`progress_automated_tested`](progress_automated_tested/) | Advance cibot-tested issues through testing states. |
| [`delay_awaiting_issues`](delay_awaiting_issues/) | Officially delay awaiting-integration issues. |
| [`manage_waiting_for_feedback`](manage_waiting_for_feedback/) | Manage the "waiting for feedback" lifecycle. |
| [`send_rebase_message`](send_rebase_message/) | Send the standard rebase message. |
| [`check_marked_as_integrated`](check_marked_as_integrated/) | Cross-check fixVersions against branch commits. |
| [`set_integration_priority_to_one`](set_integration_priority_to_one/) | Raise integration priority to 1. |
| [`set_integration_priority_to_zero`](set_integration_priority_to_zero/) | Lower integration priority to 0. |
| [`remove_ci_label_from_waiting_integration`](remove_ci_label_from_waiting_integration/) | Drop `ci` label to trigger prechecks. |
| [`remove_ci_label_from_wip`](remove_ci_label_from_wip/) | Drop `ci` label from WIP/reopened issues. |
| [`bulk_precheck_issues`](bulk_precheck_issues/) | Bulk-run the prechecker over queued issues. |
| [`bulk_prelaunch_jobs`](bulk_prelaunch_jobs/) | Launch Jenkins jobs in bulk for issues. |
| [`count_delayed_last_cycle`](count_delayed_last_cycle/) | Statistics: delayed issues last cycle. |
| [`count_reopened_last_cycle`](count_reopened_last_cycle/) | Statistics: reopened issues last cycle. |
| [`count_test_failed_last_cycle`](count_test_failed_last_cycle/) | Statistics: test-failed issues last cycle. |

---

See [AGENTS.md](../AGENTS.md) for repo-wide conventions.
