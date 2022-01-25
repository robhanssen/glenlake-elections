# default libraries
library(tidyverse)
library(lubridate)
library(ggrepel)
library(patchwork)
library(broom)

source("00-defaults.r")
source("01-import.r")

load("Rdata/votes.Rdata")

year_range <- eggstract(votes, year)

for (y in year_range) {

     voting <- votes %>% filter(year == y)
     QUORUM <- eggstract(voting, quorum)
     MEETINGDATE <- eggstract(voting, meetingdate)
     NUMBEROFHOMES <- eggstract(voting, numberhomes)
     YMAX_DEFAULT <- 160
     SCALING <- YMAX_DEFAULT / QUORUM
     YLABELS <- seq(0, NUMBEROFHOMES, 30)
     XLIMITS <- c(MEETINGDATE - months(1), MEETINGDATE + days(3))
     PERCENTBREAKS <- seq(0, 4 * QUORUM, 25)
     YEAR <- y

     # caption generator
     lastgen <- format(today(), format = "%b %d, %Y")
     lastupdate <- format(max(voting$date), format = "%b %d, %Y")
     capt <- paste0("\U00A9 ", YEAR, ", Glenlake Homeowners Association\nLast updated: ", lastgen, "\nLast data entry: ", lastupdate)

     # y-axis max
     votesmax <- max(voting$votesreceived)
     ymax <- ifelse(votesmax < QUORUM,
                            YMAX_DEFAULT,
                            ((votesmax * SCALING) %/% 10 + 1) * 10
                    )
     #define YLIMIT constants
     YLIMITS <- c(0, ymax)

     voting %>%
          ggplot +
               aes(x = date, y = votesreceived, label = votesreceived) +
               #geom_smooth(method="lm", lty=2, color="gray") +
               geom_point() +
               geom_line(lty = 2, color = "black") +
               scale_x_date(date_breaks = "1 week", date_labels = "%b %d", limit = XLIMITS) +
               scale_y_continuous(limit = YLIMITS, breaks = YLABELS,
                               sec.axis = sec_axis(~ . / QUORUM * 100, breaks = PERCENTBREAKS, name = "Quorum (%)")
                                ) +
               labs(x = "Date", y = "Votes received", caption = capt)  +
               geom_hline(yintercept = QUORUM, lty = 2, color = "red") +
               geom_vline(xintercept = MEETINGDATE, lty = 2, color = "red") +
               geom_label_repel(aes(date, votesreceived, label = votesreceived, fill = pastquorum), color = "white") +
               annotate("text", x = MEETINGDATE - days(28), y = QUORUM * 1.05, label = paste0("Quorum: ", QUORUM)) +
               annotate("text", x = MEETINGDATE - days(1), y = QUORUM %/% 2, label = "Annual Meeting", angle = 90) +
               theme_light() +
               theme(legend.position = "none")

     fname <- paste0("graphs/vote-tracking-", y, ".png")
     ggsave(fname)

     model <- lm(voting$votesreceived ~ voting$daysuntilelection)
     slope <- abs(coefficients(model)[2])
     intercept <- coefficients(model)[1]
     quorumdate <- (QUORUM - intercept) / slope + MEETINGDATE

     modelcomment <- paste0("Rate: ",
                     round(slope, 1),
                     " votes/day\nExpected target: ",
                     round(intercept, 0),
                     " votes\nPredicted date to pass quorum: ",
                     format(quorumdate, format = "%b %d")
                     )

     plot1 <- voting %>%
          ggplot +
               aes(x = daysuntilelection, y = votesneeded, label = votesneeded) +
               geom_point(size = 3) +
               geom_smooth(method = "lm", fullrange = TRUE, se = FALSE, lty = 2, color = "dark green") +
               geom_label_repel(aes(daysuntilelection, votesneeded, label = votesneeded)) +
               scale_x_reverse(limits = c(max(votes$daysuntilelection), -3)) +
               scale_y_continuous(limits = c(min(votes$votesneeded), max(votes$votesneeded))) +
               labs(x = "Time until election (in days)", y = "Votes still needed", caption = modelcomment) +
               geom_hline(yintercept = 0, lty = 1, color = "red") +
               geom_vline(xintercept = 0, lty = 1, color = "red") +
               theme_light()

     predictrange <- tibble(date  = seq.Date(from = min(voting$date),
                                                 to = MEETINGDATE + days(7),
                                                 by = "1 day"))


     predictedvotes <- voting %>%
              lm(votesreceived ~ date, data = .) %>%
              augment(newdata = predictrange)

     expectedvotes <- predictedvotes %>%
                    filter(date == MEETINGDATE) %>%
                    pull(.fitted) %>%
                    floor(.)

     targetdate <- find_value(predictedvotes$date, predictedvotes$.fitted, target = 120)

     plot2 <-
          voting %>%
          ggplot +
          aes(x = date, y = votesreceived) +
          #geom_smooth(method = "lm", lty = 2, color = "gray") +
          geom_point() +
          #      geom_line(lty = 2, color = "black") +
          scale_x_date(date_breaks = "1 week", date_labels = "%b %d", limit = XLIMITS) +
          scale_y_continuous(limit = YLIMITS, breaks = YLABELS,
                         sec.axis = sec_axis(~ . / QUORUM * 100, breaks = PERCENTBREAKS, name = "Quorum (%)")
                         ) +
          labs(x = "Date", y = "Votes received", caption = capt)  +
          geom_hline(yintercept = QUORUM, lty = 2, color = "red") +
          geom_vline(xintercept = MEETINGDATE, lty = 2, color = "red") +
          geom_vline(xintercept = targetdate, color = "purple", lty = 3) +
          #      geom_label_repel(aes(date, votesreceived, label = votesreceived, fill = pastquorum), color="white") +
          annotate("text", x = MEETINGDATE - days(28), y = QUORUM * 1.05, label = paste0("Quorum: ", QUORUM)) +
          annotate("text", x = MEETINGDATE - days(28), y = QUORUM * 0.90, label = paste0("Quorum date:\n", format(targetdate, format = "%b %d, %Y"))) +
          annotate("text", x = MEETINGDATE - days(28), y = QUORUM * 0.75, label = paste0("Expected votes:\n", expectedvotes)) +
          annotate("text", x = MEETINGDATE - days(1), y = QUORUM %/% 2, label = "Annual Meeting", angle = 90) +
          theme_light() +
          theme(legend.position = "none") +
          geom_line(data = predictedvotes, aes(y = .fitted, label = NULL), color = "gray50", lty = 1)

       joint_plot <- plot1 + plot2
       fname <- paste0("graphs/vote-expectation-", y, ".png")
       ggsave(fname, plot = joint_plot, width = 12, height = 6)
}