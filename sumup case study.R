install.packages("ggplot2")
library(sqldf)
library(ggplot2)

setwd("C:/Users/Lenovo/Downloads/")
dt <- read.csv("case_study_data_lead_ops.csv")

##### Q1: The resolution window is 7 days; we would like to optimise this timeframe. Recommend a new one and justify #####

answer1 <- sqldf("
WITH lead as (
-- Step 1: calculate days difference between the next interaction within the same classification
SELECT
  MERCHANT_CODE,
  interaction_id,
  interaction_channel, -- assumption: if a customer follows up on the same topic but using a different channel, the interaction should count as unresolved
  CREATED_DATE,
  
  -- previous interaction date per merchant
  LEAD(CREATED_DATE) OVER (
      PARTITION BY MERCHANT_CODE, classification_product
      ORDER BY CREATED_DATE
  ) AS next_interaction_date,
  
  -- number of days between the interaction and the follow up
  julianday(
        LEAD(CREATED_DATE) OVER (
            PARTITION BY MERCHANT_CODE, classification_product
            ORDER BY CREATED_DATE
        )
      ) - julianday(CREATED_DATE) AS date_diff
  
FROM dt
WHERE merchant_code != 8817975702393619456 -- excluding outlier with 73K interactions
ORDER BY MERCHANT_CODE, cREATED_DATE
)

-- Step 2: aggregate the data to find the optimal resolution window
SELECT
  date_diff,
  count(interaction_id) as interaction_count,
  count(interaction_id) * 100 / SUM(count(interaction_id)) OVER () as pct_of_total,
  CASE
  WHEN date_diff IS NULL THEN 'No follow-up'
  WHEN date_diff >= 14 THEN '14+ days'
  ELSE CAST(date_diff AS TEXT)
END AS date_diff_label
FROM lead
GROUP BY date_diff
ORDER BY date_diff ASC
                 ")
## Download results as csv for visualizations
write.csv(answer1, "answer1_results.csv", row.names = FALSE)


##### Q2: Which channel performed the best/worst in each country in 2024? #####
answer2 <- sqldf("SELECT 
INTERACTION_CHANNEL,
MERCHANT_COUNTRY,
count(INTERACTION_ID) as interaction_count,
count(distinct merchant_code) as merchants_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) AS resolved_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) 
    * 1.0 / COUNT(INTERACTION_ID) AS FCR_ratio,
avg(INTERACTION_HANDLING_TIME/60) AS AHT_min,
count(INTERACTION_ID) * 1.0/count(distinct merchant_code) as interactions_per_merchant
                  FROM dt
                  GROUP BY INTERACTION_CHANNEL, MERCHANT_COUNTRY")

## Download results as csv for visualizations
write.csv(answer2, "answer2_results.csv", row.names = FALSE)

## Separate chat due to the issues before Dec
answer2.chat <- sqldf("SELECT 
INTERACTION_CHANNEL,
MERCHANT_COUNTRY,
count(INTERACTION_ID) as interaction_count,
count(distinct merchant_code) as merchants_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) AS resolved_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) 
    * 1.0 / COUNT(INTERACTION_ID) AS FCR_ratio,
avg(INTERACTION_HANDLING_TIME/60) AS AHT_min,
count(INTERACTION_ID) * 1.0/count(distinct merchant_code) as interactions_per_merchant
                  FROM dt
                  WHERE created_date >= '2024-12-05'
                    AND INTERACTION_CHANNEL='chat'
                  GROUP BY INTERACTION_CHANNEL, MERCHANT_COUNTRY")


## Exclude 5% of the most extreme handling times from Emails
answer2.email <- sqldf("SELECT 
INTERACTION_CHANNEL,
MERCHANT_COUNTRY,
count(INTERACTION_ID) as interaction_count,
count(distinct merchant_code) as merchants_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) AS resolved_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) 
    * 1.0 / COUNT(INTERACTION_ID) AS FCR_ratio,
avg(INTERACTION_HANDLING_TIME/60) AS AHT_min,
count(INTERACTION_ID) * 1.0/count(distinct merchant_code) as interactions_per_merchant
                  FROM dt
                  WHERE INTERACTION_HANDLING_TIME <= 20000 -- 95% of interactions for this channel are handled under 20,000 sec
                    AND INTERACTION_CHANNEL='email'
                  GROUP BY INTERACTION_CHANNEL, MERCHANT_COUNTRY")

##### Q3: Which Agent Company performed the best? #####
answer3 <- sqldf("SELECT 
AGENT_COMPANY,

count(INTERACTION_ID) as interaction_count,
count(distinct AGENT_ID) as agents_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) AS resolved_count,
SUM(CASE WHEN IS_RESOLVING_INTERACTION = 'true' THEN 1 ELSE 0 END) 
    * 1.0 / COUNT(INTERACTION_ID) AS FCR_ratio,
avg(INTERACTION_HANDLING_TIME/60) AS AHT_min
                  FROM dt
                  WHERE merchant_code != 8817975702393619456
                  GROUP BY AGENT_COMPANY")

## Download results as csv for visualizations
write.csv(answer3, "answer3_results.csv", row.names = FALSE)

##### Q4: What percentage of merchants contacted multiple times, and which products were most frequently recontacted?? #####

## Find % of merchants who contacted more than 1 time in 2024 regardless of channel and classification
answer4.1 <- sqldf("
WITH multi AS (
  SELECT 
    merchant_code,
    count(interaction_id) as interactions_count,
    case when count(interaction_id) > 1 then 1 else 0 end as multiple_contact
  FROM dt
    GROUP BY merchant_code
    ORDER BY interactions_count DESC
)
-- Aggregate to find % of merchants who contacted multiple times
SELECT
  COUNT(merchant_code) AS total_merchants,
  SUM(multiple_contact) AS merchants_with_multiple_contacts,
  SUM(multiple_contact) * 1.0 / COUNT(merchant_code) AS multicontact_ratio
FROM multi;
                 ")

## Find which products were most frequently recontacted 
answer4.2 <- sqldf("
WITH multi AS (
  SELECT 
    merchant_code,
    classification_product,
    COUNT(interaction_id) AS interactions_count,
    CASE WHEN COUNT(interaction_id) > 1 THEN 1 ELSE 0 END AS multiple_contact
  FROM dt
  GROUP BY merchant_code, classification_product
)

SELECT
  classification_product,
  COUNT(merchant_code) AS merchants_count,
  SUM(multiple_contact) AS merchants_with_recontact,
  SUM(multiple_contact) * 1.0 / COUNT(merchant_code) AS recontact_ratio,
  SUM(interactions_count) AS total_interactions
FROM multi
GROUP BY classification_product
ORDER BY total_interactions DESC;
                 ")

write.csv(answer4.2, "answer4_results.csv", row.names = FALSE)

##### Q5: How would you associate costs with each channel? #####


answer5 <- sqldf("
SELECT
    strftime('%Y-%m', CREATED_DATE) AS year_month,

    -- Volumes
    SUM(CASE WHEN interaction_channel = 'call' THEN 1 ELSE 0 END) AS call_interactions,
    SUM(CASE WHEN interaction_channel = 'chat' THEN 1 ELSE 0 END) AS chat_interactions,
    SUM(CASE WHEN interaction_channel = 'email' THEN 1 ELSE 0 END) AS email_interactions,
    SUM(CASE WHEN interaction_channel = 'email' AND interaction_handling_time is not null THEN 1 ELSE 0 END) AS email_handled_interactions, -- excluding emails without handling time assuming that those are contacts that don't require agents work

    -- AHT
    AVG(CASE WHEN interaction_channel = 'call' THEN INTERACTION_HANDLING_TIME ELSE NULL END)/60 AS call_handling_min,
    AVG(CASE WHEN interaction_channel = 'chat' THEN INTERACTION_HANDLING_TIME ELSE NULL END)/60 AS chat_handling_min,
    AVG(CASE WHEN interaction_channel = 'email' THEN INTERACTION_HANDLING_TIME ELSE NULL END)/60 AS email_handling_min

FROM dt
GROUP BY year_month

")

write.csv(answer5, "answer5_results.csv", row.names = FALSE)