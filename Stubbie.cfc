<cfcomponent output="false">
	<!--- Author: gregstewart - Date: 4/13/2007 --->
	<cffunction name="init" output="false" access="public" returntype="Stubbie" hint="I initialise the component">
		<cfargument name="configFilePath" type="string" required="true" hint="config file"/>

        <cfset var tmpyStruct = StructNew()/>
        <cfset var frameworkFactory = ""/>
		<cfset parseConfigFile(arguments.configFilePath)/>

        <cfset variables.paths = ArrayNew(1)/>
        <cfset tmpyStruct["prefix"] = variables.app>
        <cfset tmpyStruct["path"] = variables.path>
        <cfset ArrayAppend(variables.paths,tmpyStruct) />

        <cfset frameworkFactory = CreateObject("component","FrameworkFactory").init(variables.app,variables.path,variables.packageRoot,variables.rootPath)/>
        <cfset variables.frameworkObj = frameworkFactory.getFrameworkWrapper(variables.unitTestFramework)/>

        <cfset variables.fso = createObject("component","FileSystemObject").init(variables.path,"/")/>
        <cfset variables.util = createObject("component","Util").init(variables.path,variables.packageRoot,"/",variables.paths)/>
		<cfset variables.serverVersion = ListGetAt(server.coldfusion.productVersion,1)/>

        <cfif variables.useColdSpring>
            <cfset loadColdSpring()/>
        </cfif>

        <cfreturn this/>
	</cffunction>

    <!--- Author: gregstewart - Date: 4/13/2007 --->
	<cffunction name="build" output="false" access="public" returntype="void" hint="I build the stub test objects">

		<cfset var qryFileList = variables.fso.list(true,'*.cfc',app)/>
		<cfset var tmpyPath = ""/>
        <cfset var tmpyStubObject = ""/>
		<cfset var testForDir = ""/>
		<cfset var stubFile = ""/>
        <cfset var testCFCs = ArrayNew(1)/>
        <cfset var tmpyFile = ""/>

        <!--- Strip out everything that is not our model folder from our query --->
        <cfquery name="qryFileList" dbtype="query">
	        SELECT *
            FROM qryFileList
            WHERE package NOT LIKE '%.test%'
            <!--- AND package NOT LIKE '%.controller%'
            AND package NOT LIKE '%.filters%'
            AND package NOT LIKE '%.plugins%'
            AND Name NOT LIKE '%Listener%' --->
        </cfquery>

		<cfif qryFileList.recordCount>

			<cfif NOT DirectoryExists(variables.path & "/test")>
				<cfdirectory action="create" directory="#variables.path#/test">
			<cfelse>
				<cfif variables.serverVersion gt 6>
					<cfdirectory directory="#variables.path#/test" action="list" name="testForDir" recurse="true"/>
				<cfelse>
					<cfset testForDir = variables.fso.directoryList(variables.path&"/test","","",true)/>
				</cfif>
			</cfif>

			<cfloop query="qryFileList">

				<cfset tmpyPath = Replace(qryFileList.fullpath,variables.path,variables.path&"/test")/>
				<cfset tmpyFile = Replace(Replace(qryFileList.fullpath&"/"&qryFileList.Name,variables.path,variables.path&"/test"),".cfc","Test.cfc")/>

				<cfif NOT DirectoryExists(tmpyPath)>
					<cflog text="Created #tmpyPath#"/>
					<cfdirectory action="create" directory="#tmpyPath#" mode="777">
				</cfif>

				<cfset tmpyStubObject = createStubObject(tmpyFile,FileExists(tmpyFile))/>
				<cfset ArrayAppend(testCFCs,tmpyStubObject)/>
			</cfloop>

            <cfif NOT FileExists(variables.path&"/test/CheckScopesTest.cfc")>
	            <!--- Create the check scopes --->
				<cfset variables.frameworkObj.createCheckScopes(variables.path)/>
            </cfif>
            <cfset ArrayAppend(testCFCs,variables.path&"/test/CheckScopesTest.cfc")/>

            <!--- Create the test suite --->
			<cfset variables.frameworkObj.createTestSuite(testCFCs)/>
        </cfif>

	</cffunction>

    <!--- Author: gregstewart - Date: 4/18/2007 --->
	<cffunction name="parseConfigFile" output="false" access="private" returntype="void" hint="I parse the xml config file">
	    <cfargument name="config" type="string" required="true" />

	    <cfset var fileContents = ""/>
	    <cfset var xmlDoc = ""/>

        <cftry>
	        <cffile action="read" file="#arguments.config#" variable="fileContents">
	        <cfcatch type="application">
                <cfthrow type="stubbie.FileNotFound" detail="Could not read #arguments.config#"/>
            </cfcatch>
        </cftry>

        <cfset xmlDoc = XmlParse(fileContents)/>

	    <cfset variables.app = xmlDoc.stubbie.config.appName.XmlAttributes["value"]/>
	    <cfset variables.rootPath = Replace(xmlDoc.stubbie.config.appPath.XmlAttributes["value"],"\","/","ALL")/>
		<cfset variables.path = variables.rootPath/>
	    <cfset variables.packageRoot = xmlDoc.stubbie.config.packageRoot.XmlAttributes["value"]/>
        <cfset variables.unitTestFramework = xmlDoc.stubbie.config.unitTestFramework.XmlAttributes["value"]/>
        <cfset variables.useColdSpring = xmlDoc.stubbie.config.coldSpring.XmlAttributes["use"]/>
	    <cfset variables.coldSpringConfigPath = xmlDoc.stubbie.config.coldSpring.XmlAttributes["path"]/>
	</cffunction>

	<!--- Author: gregstewart - Date: 4/13/2007 --->
	<cffunction name="createStubObject" output="false" access="private" returntype="string" hint="I create the stub test Object">
		<cfargument name="FilePath" type="string" required="true" />
		<cfargument name="FileExists" type="boolean" required="true" />

        <cfset var tmpyStubName = ListLast(arguments.FilePath,"/")/>
		<cfset var tmpyTestCFC = ""/>
        <cfset var testMethods = ""/>
        <cfset var existingMethods = ""/>
        <cfset var cfcMethods = ""/>

        <cfset testMethods = parseMethods(Replace(Replace(arguments.FilePath,"Test.cfc",".cfc"),"/test",""))/>
        <!--- TODO: add update capibility here, if the tets object already exists we just want to append a new method --->
        <cfif arguments.FileExists>
            <cfset existingMethods = parseMethods(arguments.FilePath)/>

            <cfset testMethods = compareMethods(existingMethods,testMethods)/>
        </cfif>

        <cfset testMethods = writeMethods(testMethods)/>

        <cfsavecontent variable="tmpyTestCFC">
&lt;cfcomponent name="<cfoutput>#Replace(tmpyStubName,".cfc","")#</cfoutput>" extends="<cfoutput>#variables.frameworkObj.getTestCase()#</cfoutput>"&gt;

	&lt;!--- Test properties go here ---&gt;
	&lt;cfproperty name="variables.<cfoutput>#Replace(tmpyStubName,"Test.cfc","")#</cfoutput>" type="WEB-INF.cftags.component" hint=""/&gt;
	
    <cfif NOT arguments.FileExists><cfoutput>#createSetup(arguments.FilePath)#</cfoutput></cfif>

	&lt;!--- Tests go here ---&gt;
    <cfoutput>#testMethods#</cfoutput>

    <cfif NOT arguments.FileExists><cfoutput>#createTearDown(arguments.FilePath)#</cfoutput></cfif>

&lt;/cfcomponent&gt;
		</cfsavecontent>

        <cfset tmpyTestCFC = Replace(Replace(tmpyTestCFC,"&lt;","<","ALL"),"&gt;",">","ALL")/>

        <cffile action="write" file="#arguments.FilePath#" output="#trim(tmpyTestCFC)#"/>
        <cflog text="Created #arguments.FilePath#">
		<cfreturn arguments.FilePath/>
	</cffunction>

    <!--- Author: gregstewart - Date: 4/16/2007 --->
	<cffunction name="parseMethods" output="false" access="private" returntype="struct" hint="I'll parse the current component and return a struct of cfc information">
	    <cfargument name="cfcPath" type="string" required="true" />

	    <cfset var componentDetails = variables.util.getCFCInformation(arguments.cfcPath)/>

        <cfreturn componentDetails/>
	</cffunction>

    <!--- Author: gregstewart - Date: 7/11/2007 --->
	<cffunction name="loadColdSpring" output="false" access="private" returntype="void" hint="I load the cs framework and initialise it with the cs file supplied">
	    <!--- void loadBeansFromXmlFile(string beanDefinitionFile, boolean ConstructNonLazyBeans) --->
        <cfset variables.myBeanFactory = createObject("component","coldspring.beans.DefaultXmlBeanFactory").init()/>

        <cfif variables.coldSpringConfigPath eq "">
            <cfthrow type="STUBBIE_COLDSPRING_CONFIG_ERROR" message="No coldspring config file supplied">
        </cfif>

        <cfif NOT FileExists(variables.path&"/"&variables.coldSpringConfigPath)>
            <cfthrow type="STUBBIE_COLDSPRING_CONFIG_ERROR" message="No coldspring config file found: #variables.path&variables.coldSpringConfigPath#">
        </cfif>

        <cfset variables.myBeanFactory.loadBeansFromXmlFile(variables.path&"/"&variables.coldSpringConfigPath,true)/>
        <!--- <cfdump var="#variables.myBeanFactory.GETBEANDEFINITIONLIST()#"/><cfabort /> --->
        <cflog text="ColdSpring bean factory loaded">
    </cffunction>

    <!--- Author: gregstewart - Date: 4/23/2007 --->
	<cffunction name="compareMethods" output="false" access="public" returntype="struct" hint="I compare the test cfc to it's equivalent and look for new methods. If found I add them to the test struct">
	    <cfargument name="existing" type="struct" required="true" />
	    <cfargument name="cfcMethods" type="struct" required="true" />

        <cfset var i = ""/>

        <cfloop collection="#arguments.cfcMethods.methods#" item="i">
            <cfif NOT StructKeyExists(arguments.existing.methods,"test"&i)>
                <cfset StructInsert(arguments.existing.methods,i,arguments.cfcMethods.methods[i])/>
            </cfif>
        </cfloop>

	    <cfreturn arguments.existing />
	</cffunction>

    <!--- Author: gregstewart - Date: 4/23/2007 --->
	<cffunction name="writeMethods" output="false" access="public" returntype="string" hint="I take the result of the parse method and write it out as a string of test methods">
	    <cfargument name="componentDetails" type="struct" required="true" />

	    <cfset var i = ""/>
	    <cfset var output = ""/>
	    <cfset var methodList = StructKeyList(arguments.componentDetails['methods'])/>
		<cfset var listPos = ListFind(methodList,"setUp")/>

		<cfif listPos gt 0>
			<!--- Let's sort this list of methods a little --->
			<cfset methodList = ListDeleteAt(methodList,listPos)/>
			<cfset methodList = ListPrepend(methodList,"setUp")/>
		</cfif>
		<cfset listPos = ListFind(methodList,"tearDown")/>
		<cfif listPos gt 0>
			<cfset methodList = ListDeleteAt(methodList,listPos)/>
			<cfset methodList = ListAppend(methodList,"tearDown")/>
		</cfif>

        <cfsavecontent variable="output">
            <cfloop list="#methodList#" index="i">
				<cfoutput>#chr(10)#</cfoutput>
                <cfif REFind("^(test)",arguments.componentDetails['methods'][i]['name']) OR REFind("tearDown|setUp",arguments.componentDetails['methods'][i]['name'])><!--- TODO: The regex for tearDown and setUp could be better --->
    <cfoutput>#arguments.componentDetails['methods'][i]['fulltag']#</cfoutput>
                <cfelse>
	<cfoutput>#variables.frameworkObj.getDummyTestMethod(arguments.componentDetails['methods'][i]['name'])#</cfoutput>
                </cfif>
            </cfloop>
	    </cfsavecontent>

	    <cfreturn trim(output)/>

	</cffunction>

    <!--- Author: gregstewart - Date: 4/24/2007 --->
	<cffunction name="createSetup" output="false" access="public" returntype="string" hint="I create the setup method">
		<cfargument name="filePath" type="string" required="true" />
	    <cfset var output = ""/>
	    <cfset var componentDetails = variables.util.getCFCInformation(ReReplace(arguments.filePath,"/*(T|t)est","","ALL")) />
	    
	    <!--- TODO: It would be really good if we had a swicth to test for CS and if so check the init method for this object
                    and try to create one with with the CS specified dependencies:
                    - We'd need to look what the constructor arg names are
                    - Whether they exist in the CS file
                    - If they do add CS to the set up method and ask CS for that object --->
	    <cfsavecontent variable="output">
	<cfoutput>#chr(10)#</cfoutput>
	&lt;cffunction name="setUp" returntype="void" access="private" output="false" hint="I set up any test data or test requirements"&gt;
	    &lt;!--- Test set up goes here ---&gt;
	    &lt;cfset variables.<cfoutput>#componentDetails.Name#</cfoutput> =  CreateObject("component","<cfoutput>#componentDetails.package#.#componentDetails.name#</cfoutput>").init() /&gt;
	&lt;/cffunction&gt;
	<cfoutput>#chr(10)#</cfoutput>
	    </cfsavecontent>

	    <cfreturn trim(output)/>
	</cffunction>

    <!--- Author: gregstewart - Date: 4/24/2007 --->
	<cffunction name="createTearDown" output="false" access="public" returntype="string" hint="I create the setup method">

	    <cfset var output = ""/>

	    <cfsavecontent variable="output">
	<cfoutput>#chr(10)#</cfoutput>
	&lt;cffunction name="tearDown" output="false" access="private" returntype="void" hint="I tear down any test data"&gt;
		&lt;!--- Test tear down goes here ---&gt;
	&lt;/cffunction&gt;
	<cfoutput>#chr(10)#</cfoutput>
	    </cfsavecontent>

	    <cfreturn trim(output)/>
	</cffunction>

    <!--- Author: gregstewart - Date: 4/17/2007 --->
	<cffunction name="createBuildFile" output="false" access="private" returntype="void" hint="CFC Unit Ant">
	    <cfset var output = ""/>

	    <cfsavecontent variable="output">
	&lt;project default="test" name="MyTest"&gt;
	   &lt;property name="cfcUnitLib" value c:/workspace/cfcunit/lib /&gt;
	   &lt;property name="hostname" value="localhost " /&gt;

	   &lt;taskdef name="cfcUnit" classname="org.cfcunit.ant.CFCUnitTask" classpath="${cfcUnitLib}/ant- cfcunit.jar" /&gt;

	   &lt;target name="test"&gt;
	      &lt;cfcUnit hostname="${hostname}" testcase="org.cfcunit.tests.iapa06-alltests" verbose="true" haltonfailure="true" haltonerror="true" showstacktrace="true" /&gt;
	   &lt;/target&gt;
	&lt;/project&gt;
	    </cfsavecontent>
	</cffunction>
</cfcomponent>