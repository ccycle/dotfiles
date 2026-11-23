((([.statuses[] | {(.context): .status}] | add) // {}) as $s
  | if any($s[]; . == "failure" or . == "error") then "failure"
    elif any($s[]; . != "success") or any($expected[]; $s[.] == null) then "pending"
    else "success"
    end)
