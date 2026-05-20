# Intelligent Retention & Revenue Recovery System 

An end-to-end predictive analytics and machine learning solution designed to transition business operations from reactive churn reporting to proactive customer retention. This system identifies at-risk customers early, tiers them by urgency, and provides prescriptive "Win-back" strategies to protect up to ₦238.6M in high-value revenue. The system that predicts customer churn with 90% accuracy and deploys a prescriptive Tableau Action Center to protect ₦25.6M in revenue at risk.

##  Business Problem & Impact

* **The Challenge:** The company faced a **15.90% churn rate**, putting **₦25,589,999.98 of revenue at risk**. Churn was most aggressive among new customers and Premium Plan users within their first 3 months.
* **The Solution:** Built a 3-tier pipeline to safeguard a **₦952.8M Total Customer Lifetime Value (CLV)**.
* **The Impact:** The system accurately identifies stable customers (0.95 Precision) to prevent discount fatigue, while prioritizing 242 "VIP Rescue" accounts to recover up to **₦238.6M** in high-value revenue.

##  System Architecture

The system consists of a three-tier analytical pipeline:

1. **SQL Feature Engineering:** Formulated a *Master Feature Table* extracting behavioral indicators including spending variability, customer tenure, and growth ratios.
2. **Predictive Modeling:** Developed a machine learning classifier optimized for high sensitivity, achieving **90% accuracy** and **82% recall** for churners.
3. **Prescriptive Action Center:** Created an automated Tableau dashboard that segments at-risk users into **Red Alert**, **Yellow Alert**, and **VIP Rescue** tiers for immediate corporate intervention.

##  Key Data Insights

* **Habit > Spend:** Purchase frequency is a significantly stronger predictor of long-term retention than raw monetary spend.
* **The Value Gap:** High-value Premium users experience a sharp drop-off within the first 90 days, indicating a critical need for an optimized onboarding journey.

## 📂 Repository Structure

├── data/                  # Synthesized/Anonymized customer datasets
├── sql/                   # Feature engineering & aggregation scripts
├── models/                # Jupyter notebooks for ML training & evaluation
├── dashboard/             # Tableau workbook files / screenshots
└── README.md              # Project documentation
