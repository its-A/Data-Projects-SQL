/*Using COVID-19 DataSet fom https://ourworldindata.org/covid-deaths */


--Making sure the Data was imported correctly
SELECT *FROM CovidDeaths
WHERE continent IS NOT NULL


SELECT *
FROM CovidVaccinations


--Data I will be using (Working with CovidDeaths Data)
SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths


--Total Cases vs Total Deaths
--Shows likelihood of dying if you contract COVID in your country
Select Location, date, total_cases, total_deaths, (CONVERT(float, total_deaths) / NULLIF(CONVERT(float, total_cases), 0))*100 AS DeathPercentage
FROM CovidDeaths
WHERE location LIKE '%states%'


--Total Cases vs Population
--Shows what percentage of population got COVID
Select Location, date, population, total_cases,(total_cases/population)*100 AS ContanimatedPercentage
FROM CovidDeaths
WHERE location LIKE '%states%'
ORDER BY 1,2

--Countries with Highest Infection Rate compared to Population
SELECT Location, Population, MAX(total_cases) AS HighestInfectionCount, MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM CovidDeaths
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC

--Showing Countries with highest death count per Population
SELECT Location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location 
ORDER BY TotalDeathCount DESC


--Showing Continents with Highest Death Count
SELECT continent, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount Desc

--Global Numbers
SELECT date, SUM(CONVERT(int,new_cases)) as total_cases, SUM(CONVERT(int, new_deaths)) as total_deaths, SUM(CONVERT(int,new_deaths)) / SUM(New_Cases)*100 AS DeathPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY DATE
ORDER BY 1,2


--Joining CovidDeaths with CovidVaccinations Data
SELECT *
FROM CovidDeaths dea
JOIN CovidVaccinations vac
ON dea.location = vac.location 
AND dea.date = vac.date

--Looking at Total Population vs Vaccinations
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(float, vac.new_vaccinations)) OVER (Partition by dea.Location ORDER BY dea.location, dea.Date)AS RollingPeopleVaccinated
FROM CovidDeaths dea 
JOIN CovidVaccinations vac
ON dea.location = vac.location 
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

--Using CTE, Population vs Vaccinations
WITH PopvsVac (continent, location, date, population, new_vaccinations, rollingpeoplevaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(float, vac.new_vaccinations)) OVER (Partition by dea.Location ORDER BY dea.location, dea.Date)AS RollingPeopleVaccinated
FROM CovidDeaths dea 
JOIN CovidVaccinations vac
ON dea.location = vac.location 
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
--ORDER BY 2,3
)
SELECT *, (RollingPeopleVaccinated/Population)*100
FROM PopvsVac

--Using Temp Table, Population vs Vaccinations
DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPupulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
RollingPeopleVaccinated numeric
)
INSERT INTO #PercentPupulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(float, vac.new_vaccinations)) OVER (Partition by dea.Location ORDER BY dea.location, dea.Date)AS RollingPeopleVaccinated
FROM CovidDeaths dea 
JOIN CovidVaccinations vac
ON dea.location = vac.location 
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL


SELECT *, (RollingPeopleVaccinated/Population)*100
FROM #PercentPupulationVaccinated

--Creating View to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(float, vac.new_vaccinations)) OVER (Partition by dea.Location ORDER BY dea.location, dea.Date)AS RollingPeopleVaccinated
FROM CovidDeaths dea 
JOIN CovidVaccinations vac
ON dea.location = vac.location 
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL

SELECT *
FROM PercentPopulationVaccinated