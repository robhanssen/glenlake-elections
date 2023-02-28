all <-
    board_tenure_raw %>%
    filter(board > 2017)

fullterm <-
    board_tenure_raw %>%
    filter(board > 2017) %>%
    filter(start %in% meetingdates & resignation %in% meetingdates)

active <-
    board_tenure_raw %>%
    filter(board > 2017) %>%
    filter(active == 1)

resigned <- bind_rows(
    # elected, resigned
    board_tenure_raw %>%
        filter(board > 2017) %>%
        filter(start %in% meetingdates & !(resignation %in% meetingdates)),

    # appointed, resigned
    board_tenure_raw %>%
        filter(board > 2017) %>%
        filter(!(start %in% meetingdates) & !(resignation %in% meetingdates))
) %>%
    filter(active == 0) %>%
    arrange(tenure)

appointed <-
    board_tenure_raw %>%
    filter(board > 2017) %>%
    filter(!(start %in% meetingdates) | resignation != today() & active == 1) %>%
    arrange(tenure)

tenure_summary <-
    glue::glue("Out of the total {nrow(all)} board positions,\n",
            "{nrow(fullterm)} members completed their full term\n",
            "while {nrow(resigned)} resigned prematurely. There\n",
            "were {nrow(appointed)} mid-term appointments.")

board_member_count <- board_tenure_raw %>% count(name) %>% nrow()