# Intelligent Retention & Revenue Recovery System 

An end-to-end predictive analytics and machine learning solution designed to transition business operations from reactive churn reporting to proactive customer retention. This system identifies at-risk customers early, tiers them by urgency, and provides prescriptive "Win-back" strategies to protect up to ₦238.6M in high-value revenue. The system that predicts customer churn with 90% accuracy and deploys a prescriptive Tableau Action Center to protect ₦25.6M in revenue at risk.

## Project Overview
This project transitions business operations from reactive churn reporting to proactive customer retention. By combining SQL feature engineering, a machine learning classifier, and an automated Tableau Action Center, the system flags at-risk customers before they churn and prescribes targeted "Win-back" strategies to protect long-term revenue.

## Project Title
Intelligent Retention & Revenue Recovery System

## Business Problem
The company is facing a **15.90% churn rate**, resulting in **₦25,589,999.98 of Revenue At Risk**. Churn is most aggressive among New Customers (181 accounts) and Premium Plan users, typically occurring within the first 3 months of the customer lifecycle. The objective is to deploy early interventions to protect the ₦952.8M Total Customer Lifetime Value (CLV).

## Tools Used
* **SQL:** Feature engineering, historical data aggregation, and Master Feature Table creation.
* **Python (Scikit-Learn / Pandas):** Machine learning model development, predictive classification, and evaluation.
* **Tableau:** Interactive dashboard design, customer tiering automation, and Prescriptive Action Center deployment.

## Analysis Approach
The system is built on a structured three-tier analytical pipeline:
1. **SQL Feature Engineering:** Engineered a *Master Feature Table* tracking critical behavioral indicators such as spending variability, tenure, and growth ratios.
2. **Predictive Modeling:** Developed a machine learning classifier optimized for high sensitivity, achieving **90% accuracy** and **82% recall** specifically for churners.
3. **Prescriptive Action Center:** Created an automated Tableau dashboard that dynamically segments at-risk users into **Red Alert**, **Yellow Alert**, and **VIP Rescue** tiers for immediate targeted business actions.

## Visuals
[Dashboard1](https://github.com/akandug/intelligent-retention-system/blob/main/Dashboard1.PNG)

## Insights and Recommendations
* **Insight:** Habit (purchase frequency) is a much stronger predictor of retention than raw spend (monetary value). High-value Premium users are the least retained, exposing a critical "Value Gap" in their first 90 days.
* **Recommendation:** Implement a specialized 90-day "Premium Onboarding" journey. Immediately prioritize outreach to the 242 **VIP Rescue** customers who represent the largest share of at-risk revenue (**₦238.6M**).

## Machine Learning Business Implication
By leveraging a model with **0.95 Precision for stable customers**, the business minimizes false alarms and avoids "discount fatigue" by only targeting customers who are truly at risk. Successfully executing the dashboard's "Action Table" can recover up to **₦238.6M** in high-value revenue and stabilize the long-term growth of the ₦672M stable customer base.

