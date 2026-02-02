--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Debian 16.4-1.pgdg110+2)
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg110+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: mocking; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mocking;


--
-- Name: staging; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA staging;


--
-- Name: tiger; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tiger;


--
-- Name: tiger_data; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tiger_data;


--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: postgis_raster; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_raster WITH SCHEMA public;


--
-- Name: postgis_tiger_geocoder; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tbproject; Type: TABLE; Schema: mocking; Owner: -
--

CREATE TABLE mocking.tbproject (
    projectid integer,
    plandays integer,
    updateddate timestamp without time zone DEFAULT now()
);


--
-- Name: vmockqualitysummary; Type: VIEW; Schema: mocking; Owner: -
--

CREATE VIEW mocking.vmockqualitysummary AS
 SELECT businessrule,
    datasetcode,
    "TableName",
    businessrulename,
    uid,
    errorfield,
    mode() WITHIN GROUP (ORDER BY errordescription) AS errordescription,
    sum("RecordCount") AS recordcount,
    min(createddate) AS createddate,
    max(updateddate) AS updateddate
   FROM ( SELECT 'C1'::text AS businessrule,
            'D_C01_001'::text AS datasetcode,
            'tbProject'::text AS "TableName",
            tbproject.projectid AS uid,
            'Duplicate ProjectId'::text AS businessrulename,
            'ProjectId'::text AS errorfield,
            'ProjectId is duplicated'::text AS errordescription,
                CASE
                    WHEN (count(*) OVER (PARTITION BY tbproject.projectid) > 1) THEN 1
                    ELSE 0
                END AS "RecordCount",
            tbproject.updateddate AS createddate,
            tbproject.updateddate
           FROM mocking.tbproject
        UNION ALL
         SELECT 'C1'::text AS businessrule,
            'D_C01_001'::text AS datasetcode,
            'tbProject'::text AS "TableName",
            tbproject.projectid AS uid,
            'Project Must contain relevant information'::text AS businessrulename,
            'PlanDays'::text AS errorfield,
            'PlanDates is missing'::text AS errordescription,
                CASE
                    WHEN (tbproject.plandays IS NULL) THEN 1
                    ELSE 0
                END AS "RecordCount",
            tbproject.updateddate AS createddate,
            tbproject.updateddate
           FROM mocking.tbproject
        UNION ALL
         SELECT 'C1'::text AS businessrule,
            'D_C01_001'::text AS datasetcode,
            'tbProject'::text AS "TableName",
            tbproject.projectid AS uid,
            'Project PlanDays shouldn''t be negative number'::text AS businessrulename,
            'PlanDays'::text AS errorfield,
            'PlanDates shouldn''t be negative'::text AS errordescription,
                CASE
                    WHEN (tbproject.plandays < 0) THEN 1
                    ELSE 0
                END AS "RecordCount",
            tbproject.updateddate AS createddate,
            tbproject.updateddate
           FROM mocking.tbproject) summary
  GROUP BY businessrule, datasetcode, "TableName", businessrulename, uid, errorfield
  ORDER BY businessrule, datasetcode, "TableName", businessrulename, uid, errorfield;


--
-- Name: tbbudgetrequest; Type: TABLE; Schema: staging; Owner: -
--

CREATE TABLE staging.tbbudgetrequest (
    budgetrequestid integer NOT NULL,
    createddate timestamp without time zone,
    createdby character varying(256),
    updateddate timestamp without time zone,
    updatedby character varying(256),
    budgetyearno integer,
    budgetrequested numeric(18,2),
    requesterunit integer,
    "position" public.geography,
    budgetrequestyearlytypeid integer,
    entitystatusid integer,
    beginperiodcustomeramount numeric(18,2),
    increasecustomeramount numeric(18,2),
    decreasecustomeramount numeric(18,2),
    watersoldqty numeric(18,2),
    waterproducedqty numeric(18,2),
    waterproductionqty numeric(18,2),
    imageid integer,
    approveddate timestamp without time zone,
    approveduserid integer,
    approvedbudgetamount numeric(18,2),
    requestid integer,
    allocatedbudgetamount numeric(18,2),
    budgetrequestnumber character varying(450),
    trusteeunitid integer,
    activitytypeid integer,
    addwaterprod numeric(18,2),
    addwateruseramount integer,
    amountofwaterincrease text,
    analyzebc numeric(18,2),
    analyzeirr numeric(18,2),
    analyzenpv numeric(18,2),
    coordinatoremail character varying(64),
    coordinatorname character varying(256),
    coordinatorposition character varying(256),
    coordinatortel character varying(64),
    discriminator text,
    durablegoodsid integer,
    endlocation public.geography,
    endpaymentyear integer,
    existpiperepairamount integer,
    existpipesize numeric(18,2),
    existpipetypeid integer,
    existpipewaterloss numeric(18,2),
    existpipeyear integer,
    existwaterprod numeric(18,2),
    existwateruseramount integer,
    goodsnewamount integer,
    goodsnewpriceperamount numeric(18,2),
    goodsnewtotal numeric(18,2),
    goodsnewunit character varying(64),
    goodsreasonitemtypeid integer,
    hasprojectlimit1m1 boolean,
    hasprojectlimit1m2 boolean,
    installmeteramount integer,
    installmetersize integer,
    installmetertypeid integer,
    installmeterwaterloss numeric(18,2),
    integrationamphoeid integer,
    integrationareatext character varying(2048),
    integrationbenefit character varying(2048),
    integrationcoordinatoremail character varying(256),
    integrationcoordinatorname character varying(256),
    integrationcoordinatorposition character varying(256),
    integrationcoordinatortel character varying(256),
    integrationevaduration character varying(256),
    integrationevaequipment character varying(2048),
    integrationevaimplement character varying(2048),
    integrationguideline character varying(2048),
    integrationindicator character varying(256),
    integrationispresident boolean,
    integrationisresolution boolean,
    integrationisstatusother boolean,
    integrationisunderprovince boolean,
    integrationobjective character varying(2048),
    integrationoperation character varying(256),
    integrationoutput character varying(2048),
    integrationplanid integer,
    integrationpolicy text,
    integrationposition public.geography,
    integrationpresidentdate timestamp without time zone,
    integrationprojecttypeid integer,
    integrationprovinceid integer,
    integrationqualitative character varying(2048),
    integrationquantitative character varying(2048),
    integrationreason character varying(2048),
    integrationref character varying(256),
    integrationresolutiondate timestamp without time zone,
    integrationresponsibleemail character varying(256),
    integrationresponsiblename character varying(256),
    integrationresponsibleposition character varying(256),
    integrationresponsibletel character varying(256),
    integrationresult character varying(2048),
    integrationstatusother character varying(256),
    integrationstrategic text,
    integrationtambonid integer,
    integrationtarget character varying(2048),
    integrationunderprovinceid integer,
    integrationunitresponsible character varying(256),
    isdeleted boolean,
    itnewamount integer,
    itnewpriceperamount numeric(18,2),
    itnewtotal numeric(18,2),
    itnewunit character varying(64),
    itreasonitemtypeid integer,
    landamount numeric(18,2),
    landenteryear integer,
    landpricecompany numeric(18,2),
    landpricecurrent numeric(18,2),
    landpriceunit numeric(18,2),
    landreason character varying(2048),
    landrequestbudget numeric(18,2),
    landrequestbudgetperitem numeric(18,2),
    nationstrategicplanitemid integer,
    needreason character varying(2048),
    newlanddate timestamp without time zone,
    newlandtypeid integer,
    newpipelength numeric(18,2),
    newpipesize numeric(18,2),
    newpipetypeid integer,
    newpipewaterloss numeric(18,2),
    operationareatext character varying(1024),
    pastprojectid integer,
    planday integer,
    polygon public.geography,
    powerreserve numeric(18,2),
    powerreservecontentsummary character varying(2048),
    powerreserveeffect character varying(2048),
    powerreserveinstalldatetime timestamp without time zone,
    powerreservenumber text,
    powerreservereason character varying(2048),
    powerreserveresultoutcome character varying(2048),
    pricereserve numeric(18,2),
    pricereservegoods numeric(18,2),
    projectboq1date timestamp without time zone,
    projectboq2date timestamp without time zone,
    projectboqtypeid integer,
    projectdurationtypeid integer,
    projectenddate timestamp without time zone,
    projectformat1date timestamp without time zone,
    projectformat2date timestamp without time zone,
    projectformattypeid integer,
    projectid integer,
    projectjobasset character varying(64),
    projectjobtypeid integer,
    projectlimit1m1date timestamp without time zone,
    projectlimit1m2date timestamp without time zone,
    projectname character varying(256),
    projectshortname character varying(40),
    projectstartdate timestamp without time zone,
    projecttor1date timestamp without time zone,
    projecttor2date timestamp without time zone,
    projecttortypeid integer,
    projectwater1date timestamp without time zone,
    projectwater2date timestamp without time zone,
    projectwatertypeid integer,
    reserveofurgent numeric(18,2),
    reserveofurgentcontentsummary character varying(2048),
    reserveofurgentdrought numeric(18,2),
    reserveofurgenteffect character varying(2048),
    reserveofurgentnumber text,
    reserveofurgentpipe numeric(18,2),
    reserveofurgentpipelength numeric(18,2),
    reserveofurgentreason character varying(2048),
    reserveofurgentresultoutcome character varying(2048),
    reserveofurgenttypeid integer,
    responsibleamphoeid integer,
    responsibleemail character varying(64),
    responsiblename character varying(256),
    responsibleposition character varying(256),
    responsibleprovinceid integer,
    responsibletambonid integer,
    responsibletel character varying(64),
    responsibleunitid integer,
    responsibleunittext character varying(512),
    roipipediameter numeric(18,2),
    roipipelength numeric(18,2),
    roipipetotallength numeric(18,2),
    roipipetype text,
    score numeric(18,2),
    startlocation public.geography,
    startpaymentyear integer,
    strategicindicator character varying(1024),
    strategicindicatorkpi character varying(1024),
    strategicobjective character varying(1024),
    strategicoutput character varying(1024),
    strategicplanitemid integer,
    strategicresourceemployee character varying(256),
    strategicresourceequipment character varying(256),
    strategicresourcetech character varying(256),
    strategicresult character varying(1024),
    uselanddate timestamp without time zone,
    uselandtypeid integer,
    waterother character varying(256),
    hasexistland boolean,
    hasnewland boolean,
    hasuseland boolean,
    waterproblem character varying(2048),
    waterproblemconform boolean,
    waterprojectdetail character varying(2048),
    operationbudgetrequestid integer,
    budgetdroughtglcodeid integer,
    disbursestatusid integer,
    priceperunit numeric(18,2),
    processingtimedays integer,
    referdocumentid integer,
    remark text,
    requestname text,
    supportingdocumentid integer,
    unitamount numeric(18,2),
    investbudgetrequestid integer,
    sapstatusid integer,
    budgetrequesttypeid integer,
    budgetrequeststatusid integer,
    wholeinvestbudgetrequested numeric(18,2),
    river character varying(1024),
    referencenumber text,
    strategicplaniteminworkid integer,
    linkdocument text,
    referencedate timestamp without time zone,
    referencenote text,
    newlandwaitdate timestamp without time zone,
    projectpipe1date timestamp without time zone,
    projectpipe2date timestamp without time zone,
    projectpipetypeid integer,
    uselandwaitdate timestamp without time zone,
    kpiunit text,
    projectkpi text,
    targetname text,
    targetunit text,
    budgetrequestedextended numeric(18,2),
    wholeinvestbudgetrequestedextended numeric(18,2),
    durablegoodsnewid integer,
    projectnameforrename character varying(256),
    changebudgetyearlytype boolean,
    projecttypeid integer,
    provincialallocationstate integer,
    treasuryamountdetail text,
    approvedwholeinvestbudgetrequested numeric(18,2),
    budgetbyprovincialdistrict numeric(18,2),
    budgetbyprovincialvicegovernor numeric(18,2),
    landamountfield numeric(18,2),
    landamountmeter numeric(18,2),
    landamountwa numeric(18,2),
    landamountwork numeric(18,2),
    leasingtypeid integer,
    activitytypecustomid integer,
    firstyearbudgetrequested numeric(18,2),
    secondyearbudgetrequested numeric(18,2),
    thirdyearbudgetrequested numeric(18,2),
    referenceuploadid text,
    costcenterid integer,
    referenceuploadcode text,
    durablecategorycode text,
    sapunitid integer,
    duplicatedcount integer,
    tbproject_projectid integer,
    recordstatus character varying(32)
);


--
-- Name: tbproject; Type: TABLE; Schema: staging; Owner: -
--

CREATE TABLE staging.tbproject (
    projectid integer NOT NULL,
    createddate timestamp without time zone,
    createdby character varying(256),
    updateddate timestamp without time zone,
    updatedby character varying(256),
    projectcode character varying(32),
    startyear integer,
    endyear integer,
    istracking boolean,
    projecttransitionid integer,
    datetime1 timestamp without time zone,
    datetime10 timestamp without time zone,
    datetime2 timestamp without time zone,
    datetime3 timestamp without time zone,
    datetime4 timestamp without time zone,
    datetime5 timestamp without time zone,
    datetime6 timestamp without time zone,
    datetime7 timestamp without time zone,
    datetime8 timestamp without time zone,
    datetime9 timestamp without time zone,
    watertoweramount numeric(18,2),
    newcapacity numeric(18,2),
    pipelength numeric(18,2),
    watertowersize numeric(18,2),
    activitytypeid integer,
    coordinatoremail character varying(64),
    coordinatorname character varying(256),
    coordinatorposition character varying(256),
    coordinatortel character varying(64),
    imageid integer,
    needreason character varying(2048),
    planday integer,
    projectdurationtypeid integer,
    projectname character varying(256),
    responsibleamphoeid integer,
    responsibleemail character varying(64),
    responsiblename character varying(256),
    responsibleposition character varying(256),
    responsibleprovinceid integer,
    responsibletambonid integer,
    responsibletel character varying(64),
    responsibleunittext character varying(512),
    addwaterprod numeric(18,2),
    addwateruseramount integer,
    amountofwaterincrease text,
    analyzebc numeric(18,2),
    analyzeirr numeric(18,2),
    analyzenpv numeric(18,2),
    durablegoodsid integer,
    endlocation public.geography,
    existpiperepairamount integer,
    existpipesize numeric(18,2),
    existpipetypeid integer,
    existpipewaterloss numeric(18,2),
    existpipeyear integer,
    existwaterprod numeric(18,2),
    existwateruseramount integer,
    goodsnewamount integer,
    goodsnewpriceperamount numeric(18,2),
    goodsnewtotal numeric(18,2),
    goodsnewunit character varying(64),
    goodsreasonitemtypeid integer,
    installmeteramount integer,
    installmetersize integer,
    installmetertypeid integer,
    installmeterwaterloss numeric(18,2),
    itnewamount integer,
    itnewpriceperamount numeric(18,2),
    itnewtotal numeric(18,2),
    itnewunit character varying(64),
    itreasonitemtypeid integer,
    landamount numeric(18,2),
    landenteryear integer,
    landpricecompany numeric(18,2),
    landpricecurrent numeric(18,2),
    landpriceunit numeric(18,2),
    landreason character varying(2048),
    landrequestbudget numeric(18,2),
    landrequestbudgetperitem numeric(18,2),
    newpipelength numeric(18,2),
    newpipesize numeric(18,2),
    newpipetypeid integer,
    newpipewaterloss numeric(18,2),
    operationareatext character varying(1024),
    polygon public.geography,
    powerreserve numeric(18,2),
    powerreservecontentsummary character varying(2048),
    powerreserveeffect character varying(2048),
    powerreserveinstalldatetime timestamp without time zone,
    powerreservenumber text,
    powerreservereason character varying(2048),
    powerreserveresultoutcome character varying(2048),
    pricereservegoods numeric(18,2),
    reserveofurgent numeric(18,2),
    reserveofurgentcontentsummary character varying(2048),
    reserveofurgentdrought numeric(18,2),
    reserveofurgenteffect character varying(2048),
    reserveofurgentnumber text,
    reserveofurgentpipe numeric(18,2),
    reserveofurgentpipelength numeric(18,2),
    reserveofurgentreason character varying(2048),
    reserveofurgentresultoutcome character varying(2048),
    reserveofurgenttypeid integer,
    roipipediameter numeric(18,2),
    roipipelength numeric(18,2),
    roipipetotallength numeric(18,2),
    roipipetype text,
    startlocation public.geography,
    waterother character varying(256),
    waterproblem character varying(2048),
    waterproblemconform boolean,
    waterprojectdetail character varying(2048),
    requesterunit integer,
    operationbudgetamount numeric(18,2),
    investwbsid integer,
    pricereserve numeric(18,2),
    trusteeunitid integer,
    hasprojectlimit1m1 boolean,
    hasprojectlimit1m2 boolean,
    location public.geography,
    newlanddate timestamp without time zone,
    newlandtypeid integer,
    projectboq1date timestamp without time zone,
    projectboq2date timestamp without time zone,
    projectboqtypeid integer,
    projectformat1date timestamp without time zone,
    projectformat2date timestamp without time zone,
    projectformattypeid integer,
    projectjobasset character varying(64),
    projectjobtypeid integer,
    projectlimit1m1date timestamp without time zone,
    projectlimit1m2date timestamp without time zone,
    projecttor1date timestamp without time zone,
    projecttor2date timestamp without time zone,
    projecttortypeid integer,
    projectwater1date timestamp without time zone,
    projectwater2date timestamp without time zone,
    projectwatertypeid integer,
    uselanddate timestamp without time zone,
    uselandtypeid integer,
    hasexistland boolean,
    hasnewland boolean,
    hasuseland boolean,
    approvedate timestamp without time zone,
    assessmentpercent numeric(18,2),
    contractcreatedate timestamp without time zone,
    designpercent numeric(18,2),
    documentpercent numeric(18,2),
    midprice_excludevat numeric(18,2),
    midprice_includedvat numeric(18,2),
    offerdate timestamp without time zone,
    postdate timestamp without time zone,
    postnumber numeric(18,2),
    priceapprove_excludevat numeric(18,2),
    priceapprove_includedvat numeric(18,2),
    pricecontract_excludevat numeric(18,2),
    pricecontract_includedvat numeric(18,2),
    pricecreatedate timestamp without time zone,
    priceoffer_excludevat numeric(18,2),
    priceoffer_includedvat numeric(18,2),
    pricesenddate timestamp without time zone,
    publishdate timestamp without time zone,
    receiveddate timestamp without time zone,
    surveypercent numeric(18,2),
    torcreatedate timestamp without time zone,
    torenddate timestamp without time zone,
    torsenddate timestamp without time zone,
    torstartdate timestamp without time zone,
    verifypercent numeric(18,2),
    enddateconstruction timestamp without time zone,
    inspectiondate timestamp without time zone,
    startdateconstruction timestamp without time zone,
    updatedbyconstruction character varying(256),
    updatedbypurchase character varying(256),
    updatedbysurvey character varying(256),
    updateddateconstruction timestamp without time zone,
    updateddatepurchase timestamp without time zone,
    updateddatesurvey timestamp without time zone,
    committee character varying(2048),
    isfinish boolean,
    reason character varying(2048),
    supervisor character varying(2048),
    plansuccess numeric(18,2),
    problems text,
    progressreportstatusid integer,
    progressreportstepid integer,
    progressreportsummarystatusid integer,
    projectenddate timestamp without time zone,
    projectstartdate timestamp without time zone,
    realsuccess numeric(18,2),
    responsibleunitid integer,
    investbudgetamount numeric(18,2),
    wholeinvestbudgetrequested numeric(18,2),
    pumpamount numeric(18,2),
    supplystationamount numeric(18,2),
    watertankamount numeric(18,2),
    watertanksize numeric(18,2),
    river character varying(1024),
    solution text,
    updatedbysuccess character varying(256),
    updateddatesuccess timestamp without time zone,
    newlandwaitdate timestamp without time zone,
    projectpipe1date timestamp without time zone,
    projectpipe2date timestamp without time zone,
    projectpipetypeid integer,
    uselandwaitdate timestamp without time zone,
    constructionsupervisorunitid integer,
    designsupervisorunitid integer,
    procurementsupervisorunitid integer,
    integrationplanid integer,
    progressreportissuetypegroupid integer,
    progressreportissuetypeid integer,
    entitystatusid integer,
    treasuryamountdetail text,
    landamountfield numeric(18,2),
    landamountmeter numeric(18,2),
    landamountwa numeric(18,2),
    landamountwork numeric(18,2),
    leasingtypeid integer,
    activitytypecustomid integer,
    costcenterid integer,
    procurementtypeid integer,
    havebudgetrequest integer,
    sapunitid integer,
    duplicatedcount integer,
    tbbudgetrequest_projectid integer,
    tbbudgetrequest_integrationareatext character varying(2048),
    tbbudgetrequest_projectenddate timestamp without time zone,
    tbbudgetrequest_projectstartdate timestamp without time zone,
    tbmprogressreportstatus_progressreportstatusid integer,
    tbmprogressreportstatus_name character varying(256),
    tbprojectbuildingmonthlypmt_projectid integer,
    tbprojectbuildingmonthlypmt_projectbuildingmonthlypaymentid integer,
    tbprojectbuildingmonthlypmtbs_projectbuildingmonthlypaymentid integer,
    tbprojectbuildingmonthlypmtbs_gscodedetailid integer,
    tbgscodedetail_gscodedetailid integer,
    tbgscodedetail_amount numeric(18,2),
    recordstatus character varying(32)
);


--
-- Data for Name: tbproject; Type: TABLE DATA; Schema: mocking; Owner: -
--

COPY mocking.tbproject (projectid, plandays, updateddate) FROM stdin;
1	\N	2026-01-02 21:57:37.524821
1	240	2026-01-02 21:57:37.534858
3	\N	2026-01-02 21:57:37.542939
4	240	2026-01-02 21:57:37.549
1	240	2026-01-02 22:11:00.770976
5	-2	\N
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: tbbudgetrequest; Type: TABLE DATA; Schema: staging; Owner: -
--

COPY staging.tbbudgetrequest (budgetrequestid, createddate, createdby, updateddate, updatedby, budgetyearno, budgetrequested, requesterunit, "position", budgetrequestyearlytypeid, entitystatusid, beginperiodcustomeramount, increasecustomeramount, decreasecustomeramount, watersoldqty, waterproducedqty, waterproductionqty, imageid, approveddate, approveduserid, approvedbudgetamount, requestid, allocatedbudgetamount, budgetrequestnumber, trusteeunitid, activitytypeid, addwaterprod, addwateruseramount, amountofwaterincrease, analyzebc, analyzeirr, analyzenpv, coordinatoremail, coordinatorname, coordinatorposition, coordinatortel, discriminator, durablegoodsid, endlocation, endpaymentyear, existpiperepairamount, existpipesize, existpipetypeid, existpipewaterloss, existpipeyear, existwaterprod, existwateruseramount, goodsnewamount, goodsnewpriceperamount, goodsnewtotal, goodsnewunit, goodsreasonitemtypeid, hasprojectlimit1m1, hasprojectlimit1m2, installmeteramount, installmetersize, installmetertypeid, installmeterwaterloss, integrationamphoeid, integrationareatext, integrationbenefit, integrationcoordinatoremail, integrationcoordinatorname, integrationcoordinatorposition, integrationcoordinatortel, integrationevaduration, integrationevaequipment, integrationevaimplement, integrationguideline, integrationindicator, integrationispresident, integrationisresolution, integrationisstatusother, integrationisunderprovince, integrationobjective, integrationoperation, integrationoutput, integrationplanid, integrationpolicy, integrationposition, integrationpresidentdate, integrationprojecttypeid, integrationprovinceid, integrationqualitative, integrationquantitative, integrationreason, integrationref, integrationresolutiondate, integrationresponsibleemail, integrationresponsiblename, integrationresponsibleposition, integrationresponsibletel, integrationresult, integrationstatusother, integrationstrategic, integrationtambonid, integrationtarget, integrationunderprovinceid, integrationunitresponsible, isdeleted, itnewamount, itnewpriceperamount, itnewtotal, itnewunit, itreasonitemtypeid, landamount, landenteryear, landpricecompany, landpricecurrent, landpriceunit, landreason, landrequestbudget, landrequestbudgetperitem, nationstrategicplanitemid, needreason, newlanddate, newlandtypeid, newpipelength, newpipesize, newpipetypeid, newpipewaterloss, operationareatext, pastprojectid, planday, polygon, powerreserve, powerreservecontentsummary, powerreserveeffect, powerreserveinstalldatetime, powerreservenumber, powerreservereason, powerreserveresultoutcome, pricereserve, pricereservegoods, projectboq1date, projectboq2date, projectboqtypeid, projectdurationtypeid, projectenddate, projectformat1date, projectformat2date, projectformattypeid, projectid, projectjobasset, projectjobtypeid, projectlimit1m1date, projectlimit1m2date, projectname, projectshortname, projectstartdate, projecttor1date, projecttor2date, projecttortypeid, projectwater1date, projectwater2date, projectwatertypeid, reserveofurgent, reserveofurgentcontentsummary, reserveofurgentdrought, reserveofurgenteffect, reserveofurgentnumber, reserveofurgentpipe, reserveofurgentpipelength, reserveofurgentreason, reserveofurgentresultoutcome, reserveofurgenttypeid, responsibleamphoeid, responsibleemail, responsiblename, responsibleposition, responsibleprovinceid, responsibletambonid, responsibletel, responsibleunitid, responsibleunittext, roipipediameter, roipipelength, roipipetotallength, roipipetype, score, startlocation, startpaymentyear, strategicindicator, strategicindicatorkpi, strategicobjective, strategicoutput, strategicplanitemid, strategicresourceemployee, strategicresourceequipment, strategicresourcetech, strategicresult, uselanddate, uselandtypeid, waterother, hasexistland, hasnewland, hasuseland, waterproblem, waterproblemconform, waterprojectdetail, operationbudgetrequestid, budgetdroughtglcodeid, disbursestatusid, priceperunit, processingtimedays, referdocumentid, remark, requestname, supportingdocumentid, unitamount, investbudgetrequestid, sapstatusid, budgetrequesttypeid, budgetrequeststatusid, wholeinvestbudgetrequested, river, referencenumber, strategicplaniteminworkid, linkdocument, referencedate, referencenote, newlandwaitdate, projectpipe1date, projectpipe2date, projectpipetypeid, uselandwaitdate, kpiunit, projectkpi, targetname, targetunit, budgetrequestedextended, wholeinvestbudgetrequestedextended, durablegoodsnewid, projectnameforrename, changebudgetyearlytype, projecttypeid, provincialallocationstate, treasuryamountdetail, approvedwholeinvestbudgetrequested, budgetbyprovincialdistrict, budgetbyprovincialvicegovernor, landamountfield, landamountmeter, landamountwa, landamountwork, leasingtypeid, activitytypecustomid, firstyearbudgetrequested, secondyearbudgetrequested, thirdyearbudgetrequested, referenceuploadid, costcenterid, referenceuploadcode, durablecategorycode, sapunitid, duplicatedcount, tbproject_projectid, recordstatus) FROM stdin;
\.


--
-- Data for Name: tbproject; Type: TABLE DATA; Schema: staging; Owner: -
--

COPY staging.tbproject (projectid, createddate, createdby, updateddate, updatedby, projectcode, startyear, endyear, istracking, projecttransitionid, datetime1, datetime10, datetime2, datetime3, datetime4, datetime5, datetime6, datetime7, datetime8, datetime9, watertoweramount, newcapacity, pipelength, watertowersize, activitytypeid, coordinatoremail, coordinatorname, coordinatorposition, coordinatortel, imageid, needreason, planday, projectdurationtypeid, projectname, responsibleamphoeid, responsibleemail, responsiblename, responsibleposition, responsibleprovinceid, responsibletambonid, responsibletel, responsibleunittext, addwaterprod, addwateruseramount, amountofwaterincrease, analyzebc, analyzeirr, analyzenpv, durablegoodsid, endlocation, existpiperepairamount, existpipesize, existpipetypeid, existpipewaterloss, existpipeyear, existwaterprod, existwateruseramount, goodsnewamount, goodsnewpriceperamount, goodsnewtotal, goodsnewunit, goodsreasonitemtypeid, installmeteramount, installmetersize, installmetertypeid, installmeterwaterloss, itnewamount, itnewpriceperamount, itnewtotal, itnewunit, itreasonitemtypeid, landamount, landenteryear, landpricecompany, landpricecurrent, landpriceunit, landreason, landrequestbudget, landrequestbudgetperitem, newpipelength, newpipesize, newpipetypeid, newpipewaterloss, operationareatext, polygon, powerreserve, powerreservecontentsummary, powerreserveeffect, powerreserveinstalldatetime, powerreservenumber, powerreservereason, powerreserveresultoutcome, pricereservegoods, reserveofurgent, reserveofurgentcontentsummary, reserveofurgentdrought, reserveofurgenteffect, reserveofurgentnumber, reserveofurgentpipe, reserveofurgentpipelength, reserveofurgentreason, reserveofurgentresultoutcome, reserveofurgenttypeid, roipipediameter, roipipelength, roipipetotallength, roipipetype, startlocation, waterother, waterproblem, waterproblemconform, waterprojectdetail, requesterunit, operationbudgetamount, investwbsid, pricereserve, trusteeunitid, hasprojectlimit1m1, hasprojectlimit1m2, location, newlanddate, newlandtypeid, projectboq1date, projectboq2date, projectboqtypeid, projectformat1date, projectformat2date, projectformattypeid, projectjobasset, projectjobtypeid, projectlimit1m1date, projectlimit1m2date, projecttor1date, projecttor2date, projecttortypeid, projectwater1date, projectwater2date, projectwatertypeid, uselanddate, uselandtypeid, hasexistland, hasnewland, hasuseland, approvedate, assessmentpercent, contractcreatedate, designpercent, documentpercent, midprice_excludevat, midprice_includedvat, offerdate, postdate, postnumber, priceapprove_excludevat, priceapprove_includedvat, pricecontract_excludevat, pricecontract_includedvat, pricecreatedate, priceoffer_excludevat, priceoffer_includedvat, pricesenddate, publishdate, receiveddate, surveypercent, torcreatedate, torenddate, torsenddate, torstartdate, verifypercent, enddateconstruction, inspectiondate, startdateconstruction, updatedbyconstruction, updatedbypurchase, updatedbysurvey, updateddateconstruction, updateddatepurchase, updateddatesurvey, committee, isfinish, reason, supervisor, plansuccess, problems, progressreportstatusid, progressreportstepid, progressreportsummarystatusid, projectenddate, projectstartdate, realsuccess, responsibleunitid, investbudgetamount, wholeinvestbudgetrequested, pumpamount, supplystationamount, watertankamount, watertanksize, river, solution, updatedbysuccess, updateddatesuccess, newlandwaitdate, projectpipe1date, projectpipe2date, projectpipetypeid, uselandwaitdate, constructionsupervisorunitid, designsupervisorunitid, procurementsupervisorunitid, integrationplanid, progressreportissuetypegroupid, progressreportissuetypeid, entitystatusid, treasuryamountdetail, landamountfield, landamountmeter, landamountwa, landamountwork, leasingtypeid, activitytypecustomid, costcenterid, procurementtypeid, havebudgetrequest, sapunitid, duplicatedcount, tbbudgetrequest_projectid, tbbudgetrequest_integrationareatext, tbbudgetrequest_projectenddate, tbbudgetrequest_projectstartdate, tbmprogressreportstatus_progressreportstatusid, tbmprogressreportstatus_name, tbprojectbuildingmonthlypmt_projectid, tbprojectbuildingmonthlypmt_projectbuildingmonthlypaymentid, tbprojectbuildingmonthlypmtbs_projectbuildingmonthlypaymentid, tbprojectbuildingmonthlypmtbs_gscodedetailid, tbgscodedetail_gscodedetailid, tbgscodedetail_amount, recordstatus) FROM stdin;
\.


--
-- Data for Name: geocode_settings; Type: TABLE DATA; Schema: tiger; Owner: -
--

COPY tiger.geocode_settings (name, setting, unit, category, short_desc) FROM stdin;
\.


--
-- Data for Name: pagc_gaz; Type: TABLE DATA; Schema: tiger; Owner: -
--

COPY tiger.pagc_gaz (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_lex; Type: TABLE DATA; Schema: tiger; Owner: -
--

COPY tiger.pagc_lex (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_rules; Type: TABLE DATA; Schema: tiger; Owner: -
--

COPY tiger.pagc_rules (id, rule, is_custom) FROM stdin;
\.


--
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: -
--

COPY topology.topology (id, name, srid, "precision", hasz) FROM stdin;
\.


--
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: -
--

COPY topology.layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


--
-- Name: topology_id_seq; Type: SEQUENCE SET; Schema: topology; Owner: -
--

SELECT pg_catalog.setval('topology.topology_id_seq', 1, false);


--
-- Name: tbbudgetrequest tbbudgetrequest_pk; Type: CONSTRAINT; Schema: staging; Owner: -
--

ALTER TABLE ONLY staging.tbbudgetrequest
    ADD CONSTRAINT tbbudgetrequest_pk PRIMARY KEY (budgetrequestid);


--
-- Name: tbproject tbproject_pk; Type: CONSTRAINT; Schema: staging; Owner: -
--

ALTER TABLE ONLY staging.tbproject
    ADD CONSTRAINT tbproject_pk PRIMARY KEY (projectid);


--
-- PostgreSQL database dump complete
--

