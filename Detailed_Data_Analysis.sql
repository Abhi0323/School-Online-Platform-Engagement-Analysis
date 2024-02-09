-- 1.a Trying to find out total overall login percent by calculating present by total entries.
-- Answer: While following this approach I recieved 0 schools having overall teachers login percent more than 60%
SELECT 
    school_name,
    (SUM(CASE WHEN is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS login_percentage
FROM 
    TeacherActivity
GROUP BY 
    school_name
HAVING 
    (SUM(CASE WHEN is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) > 60
ORDER BY 
    login_percentage DESC
LIMIT 5;

-- 2. Teachers Login day over day change in percentage across all schools.

WITH DailyLoginPercentage AS (
    SELECT
        school_name,
        record_date,
        COUNT(DISTINCT CASE WHEN is_present = TRUE THEN teacher_id END) teacher_logged_in,
        COUNT(DISTINCT teacher_id) total_teachers,
        (COUNT(DISTINCT CASE WHEN is_present = TRUE THEN teacher_id END) * 100.0 / COUNT(DISTINCT teacher_id)) AS daily_login_percentage
    FROM 
        TEACHERACTIVITY
    GROUP BY 
        school_name, record_date
)
SELECT
    school_name,
    record_date,
    teacher_logged_in,
    total_teachers,
    daily_login_percentage,
    daily_login_percentage - LAG(daily_login_percentage, 1) OVER (PARTITION BY school_name ORDER BY record_date) AS day_over_day_change
FROM 
    DailyLoginPercentage
ORDER BY 
    school_name, record_date;

-- 3. If each billable student pays 500$/Month, what’s the revenue generated per school

SELECT 
    SCHOOL_NAME,
    COUNT(DISTINCT STUDENT_ID) total_students,
    COUNT(DISTINCT STUDENT_ID) * 500 AS REVENUE
FROM 
    STUDENTACTIVITY
WHERE 
    is_present = TRUE
GROUP BY 
    SCHOOL_NAME;


-- 4. Find the number of teachers per school who logged in 3 consecutive days

WITH TeacherAttendance AS (
    SELECT
        school_name,
        teacher_id,
        LAG(record_date, 1) OVER (PARTITION BY school_name, teacher_id ORDER BY record_date) as prev_date,
        record_date,
        LEAD(record_date, 1) OVER (PARTITION BY school_name, teacher_id ORDER BY record_date) as next_date
    FROM 
        TeacherActivity
    WHERE 
        is_present = TRUE
),
ConsecutiveLogins AS (
    SELECT
        school_name,
        teacher_id,
        prev_date,
        record_date,
        next_date
    FROM 
        TeacherAttendance
    WHERE
        record_date - INTERVAL '1 day' = prev_date AND  
        record_date + INTERVAL '1 day' = next_date      
)
SELECT
    school_name,
    COUNT(DISTINCT teacher_id) as teachers_with_consecutive_logins
FROM 
    ConsecutiveLogins
GROUP BY
    school_name
ORDER BY teachers_with_consecutive_logins DESC;


--5. Find the weekly average for student login activity per school 

WITH WeeklyLoginCount AS (
    SELECT 
        school_name,
        CASE 
            WHEN record_date BETWEEN '2020-10-25' AND '2020-10-31' THEN 'Week 1: 2020-10-25 to 2020-10-31'
            WHEN record_date BETWEEN '2020-11-01' AND '2020-11-07' THEN 'Week 2: 2020-11-01 to 2020-11-07'
        END AS week_label,
        COUNT(DISTINCT student_id) AS weekly_login_count
    FROM 
        StudentActivity
    WHERE 
        is_present = TRUE
        AND record_date BETWEEN '2020-10-25' AND '2020-11-07'
    GROUP BY 
        school_name,
        CASE 
            WHEN record_date BETWEEN '2020-10-25' AND '2020-10-31' THEN 'Week 1: 2020-10-25 to 2020-10-31'
            WHEN record_date BETWEEN '2020-11-01' AND '2020-11-07' THEN 'Week 2: 2020-11-01 to 2020-11-07'
        END
)
SELECT 
    school_name,
    AVG(weekly_login_count) AS weekly_avg_login
FROM 
    WeeklyLoginCount
GROUP BY 
    school_name
ORDER BY 
    school_name;

-- Tried different logics for the 1st question, because of not receiving any schools with more than 60% overall login%.

--1.b Now I am assuming if the teachers last date is true then they might be on a leave for the remaining days. 
---So, I am not considering the entries showing false for a teacher after their last login date is true.
--Answer: For this approach I figured out 
--1. ABU BHABI_1706 had 66.6 Login Percentage
--2. ABU BHABI_377 had 64.8 Login Percentage
--3. ABU BHABI_1530 had 63.4 Login Percentage

WITH LastLoginDate AS (
    SELECT 
        teacher_id,
        MAX(record_date) AS last_login_date
    FROM 
        TeacherActivity
    WHERE 
        is_last_login = TRUE
    GROUP BY 
        teacher_id
)
SELECT 
    ta.school_name,
    (SUM(CASE WHEN ta.is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS login_percentage
FROM 
    TeacherActivity ta
JOIN 
    LastLoginDate lld ON ta.teacher_id = lld.teacher_id
WHERE 
    ta.record_date <= lld.last_login_date
GROUP BY 
    ta.school_name
HAVING 
    (SUM(CASE WHEN ta.is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) > 60
ORDER BY 
    login_percentage DESC
LIMIT 5;


--1.c Now I am assuming that if the teachers start date is after a few days of school start date they might be a new hire or they have joined late, so I am excluding the entires prior to the first start date.
--Answer: ABU BHABI_1706 had 65.9 Login Percentage

WITH LastLoginDate AS (
    SELECT 
        teacher_id,
        MAX(record_date) AS last_login_date,
        MIN(teacher_first_login_date) AS first_login_date  
    FROM 
        TeacherActivity
    WHERE 
        is_last_login = TRUE OR teacher_first_login_date IS NOT NULL  
    GROUP BY 
        teacher_id
)
SELECT 
    ta.school_name,
    (SUM(CASE WHEN ta.is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS login_percentage
FROM 
    TeacherActivity ta
JOIN 
    LastLoginDate lld ON ta.teacher_id = lld.teacher_id
WHERE 
    ta.record_date BETWEEN lld.first_login_date AND lld.last_login_date 
GROUP BY 
    ta.school_name
HAVING 
    login_percentage > 60
ORDER BY 
    login_percentage DESC
LIMIT 5;

-- 1.d Tried to exclude teacher_first_login_date is null assuming teachers who have not at all logged in.

SELECT 
    school_name,
    (SUM(CASE WHEN is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS login_percentage
FROM 
    TeacherActivity
WHERE 
    teacher_first_login_date IS NOT NULL  
GROUP BY 
    school_name
HAVING 
    (SUM(CASE WHEN is_present = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) > 60
ORDER BY 
    login_percentage DESC
LIMIT 5;