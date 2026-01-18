# SumUp case study 
The goal of the technical test is to build data models that can create the following strategy:
1. The resolution window is 7 days; we would like to optimise this timeframe. Recommend a new one and justify.
2. Which channel performed the best/worst in each country in 2024?
3. Which Agent Company performed the best?
4. What percentage of merchants contacted multiple times, and which products were most frequently recontacted?
5. How would you associate costs with each channel?
Please add an executive summary with the support performance and how best/worst was defined.


# DATA ISSUES:
- merchant_id = 8817975702393619368 (in R 8817975702393619456) is a sole merchant code used for chats up till December (72K interactions). MCC Group available as of 5th Dec, resolution/handling times available as of 26th July. I excluded it in some of the queries where it affected the reported metric, but left it in those queries where available breakdown (for example of product classification) was more valuable than repeated merchant code.
- Chat is_resolved flag: this flag is not reliable before December as all the interactions are marked as resolved.
- Chat AHT: interaction_handling_time and interaction_response_time is null for chats up till the end of July.  
- Email resolution and handling times: it's not clear to me how the email interactions work and if those are always only inbound emails. I suspect that handling time is calculated as time difference between received timestamp and response sent timestamp, which does not reflect actual time spent working on a response since it doesn't exclude time in backlog. In an ideal world, I would try to better understand how handling time is calculated and work with operations teams on improving the tracking of actual time spent by agents on resolving the email contacts.
  
# Answers
1. Resolution window target should move to 2 days.
Following pareto rule, 80% of contacts are resolved within 2 days. 30% of interactions never get a follow up on the same topic (date_diff = NA)
Note: I calculated the days difference between the interactions regardless of the channel. My reasoning is that if a customer is reaching out on the same topic it shouldn't matter if they switch between channels.
Data caveats: 
- Sub-classifications: According to the annotation in the case document "in the dataset only high level classification is presented at product level", which suggests that there might be sub-classifications available which can further help distinguish between new interactions vs. repeated contacts.
- Email tracking: I assumed that each interaction_id for email channel is coming in the direction customer -> agent although it looks like those are both inbound and outbound interactions.

2. Performance metrics that I selected: 
   - First Contact Resolution (FCR) % - percentage of resolved interactions (NO follow-up interaction within 7 days in the same classification) out of total interactions count
   - Average Handling Time (AHT) - average time agents spent handling the interactions
   - Repeated Contact Ratio (RCR) - number of interactions divided by unique number of merchants
Due to significant data gaps (Chat) and skeweness of the data (Email AHT) it is hard to draw reliable conclusions on which channel performed the best. Call data is the most reliable.

3. To evaluate performance of companies I focused on the FCR in relation to the processed volumes and serviced channels. Company 3 showes the highest resolution rate but in the same time processed the lowest number of contacts. Deep dive is needed to better understand the reasons for better performance of Company 3 (for example: if it could be explained by contact channel distribution, agent tenure, skills, tracking issues etc.)

4. 65% of merchants contacted Customer Support more than once in 2024. The biggest opportunity sits with Profile which is the biggest in terms of number of interactions and merchants that contact Customer Support and 65% of merchants had more than 1 interaction in this category. I would be interested in better understanding the actual need behind this question, which would allow me to better advise on the metrics. For example: if our goal is to reduce merchants need to contact customer support a metric based on a rolling window of 3, 6, 12 months might be better.
  
5. Cost
Calculate monthly volumes and AHT per channel. Volumes * AHT = workload hours. Divide $0.5M by workload assuming that all companies and agents are paid the same hourly rate.

