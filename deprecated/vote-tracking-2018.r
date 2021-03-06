# default libraries
library(tidyverse)
library(lubridate)
library(ggrepel)
options(bitmapType='cairo')

#define constants
MEETINGDATE = as.Date("2018-02-03", format="%Y-%m-%d")
NUMBEROFHOMES = 460
QUORUM = NUMBEROFHOMES %/% 4  # 25% quorum requirement
YMAX_DEFAULT = 160
SCALING = YMAX_DEFAULT / QUORUM
YLABELS = seq(0,NUMBEROFHOMES,30)
XLIMITS = c(MEETINGDATE - months(1),MEETINGDATE + days(3))
PERCENTBREAKS = seq(0,4*QUORUM,25)
YEAR = 2018

# read data file
votes <- read_csv("sources/vote-tracking-2018.csv") %>% 
                    mutate(date = as.Date(date, format="%Y-%m-%d"),
                           pastquorum = ifelse(votesreceived < QUORUM, FALSE, TRUE),
                           daysuntilelection = MEETINGDATE - date,
                           votesneeded = QUORUM - votesreceived
                            )

# caption generator
lastgen = format(today(), format="%b %d, %Y")
lastupdate = format(max(votes$date), format="%b %d, %Y")
capt = paste0("\U00A9 ", YEAR,", Glenlake Homeowners Association\nLast updated: ", lastgen, "\nLast data entry: ", lastupdate)

# y-axis max
votesmax = max(votes$votesreceived)
ymax = ifelse(votesmax < QUORUM, 
                    YMAX_DEFAULT, 
                    ((votesmax * SCALING) %/% 10 + 1) * 10
                    )

#define YLIMIT constants
YLIMITS = c(0 , ymax)


votes %>% ggplot + aes(x=date, y=votesreceived, label=votesreceived) + 
            #geom_smooth(method="lm", lty=2, color="gray") + 
            geom_point() + 
            geom_line(lty=2, color="black") +
            scale_x_date(date_breaks="1 week", date_labels = "%b %d", limit=XLIMITS) + 
            scale_y_continuous(limit = YLIMITS, breaks = YLABELS, 
                               sec.axis = sec_axis(~ ./QUORUM*100, breaks=PERCENTBREAKS, name="Quorum (%)")
                                ) + 
            labs(x="Date", y="Votes received", caption=capt)  +
            geom_hline(yintercept = QUORUM, lty=2, color="red") + 
            geom_vline(xintercept = MEETINGDATE, lty = 2, color = "red") + 
            geom_label_repel(aes(date, votesreceived, label = votesreceived, fill = pastquorum), color="white") +             
            annotate("text", x = MEETINGDATE - days(28), y = QUORUM*1.05, label = paste0("Quorum: ", QUORUM)) + 
            annotate("text", x = MEETINGDATE - days(1), y = QUORUM %/% 2, label = "Annual Meeting", angle = 90) + 
            theme_light() + theme(legend.position = "none")

ggsave("graphs/vote-tracking-2018.png")
ggsave("graphs/vote-tracking-2018.pdf")

model <- lm(votes$votesreceived ~ votes$daysuntilelection)
slope = abs(coefficients(model)[2])
intercept = coefficients(model)[1]
quorumdate = (QUORUM-intercept)/slope + MEETINGDATE

modelcomment = paste0("Rate: ", 
                     round(slope, 1), 
                     " votes/day\nExpected target: ",
                     round(intercept,0), 
                     " votes\nPredicted date to pass quorum: ", 
                     format(quorumdate, format="%b %d")
                     )

votes %>% ggplot + aes(x=daysuntilelection, y=votesneeded, label=votesneeded) + 
              geom_point(size=3) + 
              geom_smooth(method="lm", fullrange=TRUE, se=FALSE, lty=2, color="dark green") + 
              geom_label_repel(aes(daysuntilelection, votesneeded, label = votesneeded)) +                           
              scale_x_reverse(limits=c(max(votes$daysuntilelection),-3))  +
              scale_y_continuous(limits=c(-3,max(votes$votesneeded))) + 
              labs(x="Time until election (in days)", y="Votes still needed", caption=modelcomment) +
              geom_hline(yintercept=0, lty=1, color="red")  +
              geom_vline(xintercept=0, lty=1, color="red")  +
              #annotate("text", x = 20, y = 30, label = modelcomment) + 
              theme_light()
              
ggsave("graphs/vote-expectation-2018.pdf")
