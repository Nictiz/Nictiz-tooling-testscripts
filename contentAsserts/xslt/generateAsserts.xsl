<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns="http://hl7.org/fhir"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:nf="http://www.nictiz.nl/functions"
    exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
        
    <!-- FHIR version to be able to retrieve the correct FHIR core resource type StructureDefinition, euther 'stu3' or 'r4'. -->
    <xsl:param name="fhirVersion"/>
    
    <!-- Fixed, but could be dependant on fhirVersion -->
    <xsl:variable name="simpleDataTypes" as="xs:string*">
        <xsl:choose>
            <xsl:when test="lower-case($fhirVersion) = 'stu3'">
                <xsl:sequence select="('boolean','integer','string','decimal','uri','base64Binary','instant','date','dateTime','time','code','oid','id','markdown','unsignedInt','positiveInt')"/>
            </xsl:when>
            <xsl:when test="lower-case($fhirVersion) = 'r4'">
                <xsl:sequence select="('boolean','integer','string','decimal','uri','url','canonical','base64Binary','instant','date','dateTime','time','code','oid','id','markdown','unsignedInt','positiveInt','uuid')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">fhirVersion is not set. This parameter is required for generating content asserts.</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="complexDataTypes" select="('Annotation','Attachment','Coding','CodeableConcept','Quantity','SimpleQuantity','Distance','Age','Count','Duration','Money','Range','Ratio','Period','SampledData','Identifier','HumanName','Address','ContactPoint','Timing','Signature','Reference','Narrative',(:'Extension',:)'Meta','Dosage')"/>
    
    <!-- This list of dataTypes is kind of arbitrary. I guess you can say that types like Reference or Quantity are somewhat compact (like max. 4 or 5 children?) that convey meaning _together_. The dataTypes below are more like bundles of elements that contain multiple individual pieces of information -->
    <xsl:variable name="containerTypes" select="('Address','BackboneElement','Element','ContactPoint','Dosage','HumanName','Timing')"/>
    
    <xsl:variable name="dataTypes" select="($simpleDataTypes, $complexDataTypes)"/>
    <xsl:variable name="dataTypesLower" select="for $i in $dataTypes return lower-case($i)"/>
    <xsl:variable name="simpleDataTypesLower" select="for $i in $simpleDataTypes return lower-case($i)"/>
    
    <xsl:param name="libPath" select="concat(string-join(tokenize(static-base-uri(), '/')[fn:position() lt last() - 1], '/'), '/lib/')"/>
    
    <!-- The "main" template. It matches not on nts:contentAsserts itself but on the containing test, because the
         result for each nts:contentAsserts will be an additional sibling test. -->
    <xsl:template match="f:test[//nts:contentAsserts]" mode="generateContentAsserts">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="referenceDirAsUrl" tunnel="yes"/> <!-- absolute file:/// URL for the base path to the fixtures -->
        
        <!-- Construct the variables for the test -->
        <xsl:variable name="requestResponseId">
            <xsl:choose>
                <xsl:when test="fn:string-length(@id) gt 0">
                    <xsl:value-of select="concat('fixture-',@id)"/>
                </xsl:when>
                <xsl:when test="count(parent::f:TestScript/f:test) = 1">
                    <xsl:text>fixture-response</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message>TOCHECK: responseId/responseId and test/@id not found, reverting to default.</xsl:message>
                    <xsl:value-of select="generate-id()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="operationType">
            <xsl:choose>
                <xsl:when test="f:action/f:operation/f:type/f:code/@value">
                    <xsl:value-of select="f:action/f:operation/f:type/f:code/@value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message>TOCHECK: unknown operationType, reverting to default (search).</xsl:message>
                    <xsl:value-of select="'search'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="testName" select="f:name/@value"/>
                
        <!-- Load all fixtures -->
        <xsl:variable name="fixtures">
            <xsl:for-each select="nts:contentAsserts">
                <xsl:variable name="href" select="@href"/>
                <xsl:variable name="fixtureUri" select="concat($referenceDirAsUrl, '/', $href)"/>
                <xsl:choose>
                    <xsl:when test="doc-available($fixtureUri)">
                        <nts:fixture href="{$href}">
                            <xsl:copy-of select="document($fixtureUri)"/>
                        </nts:fixture>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:message terminate="yes">nts:contentAsserts fixture not available: <xsl:value-of select="$fixtureUri"/></xsl:message>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- Copy the current test and its contents, with the addition of requestId or responseId if not present -->
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="generateContentAsserts.addRequestResponseId">
                <xsl:with-param name="operationType" select="$operationType" tunnel="yes"/>
                <xsl:with-param name="requestResponseId" select="$requestResponseId" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>

        <!-- Expand all nts:contentAsserts tags -->
        <xsl:for-each select="nts:contentAsserts">
            <xsl:variable name="href" select="@href"/>
            <xsl:variable name="expression" select="@expression"/>
            <xsl:variable name="bundleExpression" select="@bundleExpression"/>
            <xsl:if test="ends-with(translate($expression, ' ', ''), 'count()=1') or ends-with($expression, 'exists()') and not($bundleExpression = 'true')">
                <xsl:message terminate="yes">TOEDIT: Expression shouldn't end in count() or exists() - <xsl:value-of select="$expression"/></xsl:message>
            </xsl:if>
            <xsl:variable name="description" select="@description"/>
            
            <xsl:variable name="fixture" select="$fixtures/nts:fixture[@href = $href]/*"/>
            <xsl:variable name="fixtureId" select="$fixture/f:id/@value"/>
            
            <xsl:variable name="resourceType" select="$fixture/local-name()"/>
            <xsl:variable name="resourceCount" select="count($fixture/parent::nts:fixture/preceding-sibling::nts:fixture[*/local-name() = $resourceType]) + 1"/>
            <xsl:variable name="multipleExist" select="count($fixtures/nts:fixture[*/local-name() = $resourceType]) gt 1"/>
            
            <!-- Sanity check -->
            <xsl:if test="$multipleExist = true() and string-length($expression) = 0">
                <xsl:message terminate="yes">TOEDIT: <xsl:value-of select="$testName"/> - nts:contentAsserts with a resource type that exists multiple times (<xsl:value-of select="$resourceType"/>) SHALL contain @expression</xsl:message>
            </xsl:if>
            
            <xsl:variable name="structureDefinition" select="document(concat($libPath, lower-case($fhirVersion), '/', $resourceType, '.xml'))"/>
            
            <!-- Annotate the fixture with the metadata needed to write out the individual asserts -->
            <xsl:variable name="fixtureWithMetaData">
                <xsl:apply-templates select="$fixture" mode="generateContentAsserts.addMetaData">
                    <xsl:with-param name="structureDefinition" select="$structureDefinition" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable>
            
            <test>
                <xsl:copy-of select="parent::f:test/@nts:*"/>
                <xsl:copy-of select="@nts:*"/>
                <name>
                    <xsl:attribute name="value">
                        <xsl:value-of select="concat($testName, ' - Check ', $resourceType)"/>
                        <xsl:if test="$multipleExist = true()">
                            <xsl:value-of select="concat(' ', $resourceCount)"/>
                        </xsl:if>       
                    </xsl:attribute>
                </name>
                <description value="Check if the previous operation results in a FHIR {$resourceType} that contains the values that are expected following Nictiz' materials (fixture .id: {$fixtureId})"/>
                
                <!-- According to TestScript spec, the last available request/response will be used, so we do not specifically have to add a requestId or responseId. Could (should?) be a feature though -->

                <!-- Add assert to check that the selected resource exists exactly 1 time -->
                <xsl:call-template name="createAssert">
                    <xsl:with-param name="description">
                        <xsl:variable name="direction" select="if ($scenario = 'server') then 'Response' else 'Request'"/>
                        <xsl:choose>
                            <xsl:when test="$operationType = 'read'">
                                <xsl:value-of select="concat($direction, ' contains exactly 1 ', $resourceType)"/>
                            </xsl:when>
                            <xsl:when test="string-length($description) gt 0">
                                <xsl:value-of select="concat($direction, ' Bundle contains exactly 1 ', $resourceType, ' that ', $description)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat($direction, ' Bundle contains exactly 1 ', $resourceType)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="expression">
                        <xsl:choose>
                            <xsl:when test="$operationType = 'read'">
                                <xsl:value-of select="concat($resourceType, '.count() = 1')"/>
                            </xsl:when>
                            <xsl:when test="$bundleExpression = 'true'">
                                <xsl:value-of select="concat($expression, '.count() = 1')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat('Bundle.entry.resource.ofType(', $resourceType, ')', $expression, '.count() = 1')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="stopTestOnFail" select="true()"/>
                </xsl:call-template>
                
                <!-- Add an explicit assert to check Resource.id in case of server response checks -->
                <xsl:variable name="idVariable" select="concat($fixtureId,'-id')"/>
                <xsl:if test="$scenario = 'server'">
                    <xsl:call-template name="createAssert">
                        <xsl:with-param name="description" select="concat($resourceType, ' resource evaluated in the previous assert contains an .id')"/>
                        <xsl:with-param name="expression">
                            <xsl:choose>
                                <xsl:when test="$operationType = 'read'">
                                    <xsl:value-of select="concat($resourceType, '.id.exists()')"/>
                                </xsl:when>
                                <xsl:when test="$bundleExpression = 'true'">
                                    <xsl:value-of select="concat($expression, '.id.exists()')"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('Bundle.entry.resource.ofType(', $resourceType, ')', $expression, '.id.exists()')"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:with-param>
                        <xsl:with-param name="stopTestOnFail" select="true()"/>
                    </xsl:call-template>
                    
                    <!-- If the assert above passes, we know by definition that this variable will be evaluated. TestScripts will fail with an error if a variable cannot be evaluated, but to users it is not really clear what happens. The setup with the asserts above will prevent that hopefully. -->
                    <variable>
                        <name value="{$idVariable}"/>
                        <description value="Resource.id for {$resourceType} {$resourceCount}"/>
                        <expression>
                            <xsl:attribute name="value">
                                <xsl:choose>
                                    <xsl:when test="$operationType = 'read'">
                                        <xsl:value-of select="concat($resourceType, '.id')"/>
                                    </xsl:when>
                                    <xsl:when test="$bundleExpression = 'true'">
                                        <xsl:value-of select="concat($expression, '.id')"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="concat('Bundle.entry.resource.ofType(', $resourceType, ')', $expression, '.id')"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:attribute>
                        </expression>
                        <sourceId value="{$requestResponseId}"/>
                    </variable>
                </xsl:if>
                
                <!-- Now add all the content asserts -->
                <xsl:apply-templates select="$fixtureWithMetaData/f:*/f:*" mode="generateContentAsserts.addAsserts">
                    <xsl:with-param name="operationType" select="$operationType" tunnel="yes"/>
                    <xsl:with-param name="resourceType" select="$resourceType" tunnel="yes"/>
                    <xsl:with-param name="resourceIdExpression" tunnel="yes">
                        <xsl:choose>
                            <xsl:when test="$scenario = 'server'">
                                <xsl:value-of select="concat('.where(id = ''${', $idVariable, '}'')')"/>
                            </xsl:when>
                            <xsl:when test="$scenario = 'client' and $multipleExist = false()"/>
                            <xsl:when test="$scenario = 'client' and $multipleExist = true()">
                                <xsl:choose>
                                    <xsl:when test="$bundleExpression = 'true'">
                                        <xsl:message terminate="yes">NOT SUPPORTED</xsl:message>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="$expression"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="parentLabel" select="$resourceCount"/>
                </xsl:apply-templates>
            </test>
        </xsl:for-each>
    </xsl:template>

    <!-- Default template for the generateContentAsserts mode -->
    <xsl:template match="node()|@*" mode="generateContentAsserts">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!--
    ==========================================================================================================
    These two templates are used to inject the requestId or responseId into each operation if they are absent.
    ==========================================================================================================
    -->
    <xsl:template match="f:operation" mode="generateContentAsserts.addRequestResponseId">
        <xsl:param name="operationType" tunnel="yes"/>
        <xsl:param name="requestResponseId" tunnel="yes"/>

        <xsl:copy>
            <xsl:apply-templates select="@*" mode="generateContentAsserts.addRequestResponseId"/>
            <xsl:apply-templates select="*[not(self::f:sourceId) and not(self::f:targetId) and not (self::f:url)]" mode="#current"/>
            <xsl:if test="($operationType = ('read', 'search')) and not(.[f:responseId])">
                <responseId value="{$requestResponseId}"/>
            </xsl:if>
            <xsl:if test="($operationType = ('update', 'create')) and not(.[f:requestId])">
                <requestId value="{$requestResponseId}"/>
            </xsl:if>
            <xsl:apply-templates select="(f:sourceId | self::f:targetId | self::f:url)" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="node()|@*" mode="generateContentAsserts.addRequestResponseId">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!--
    ==================================================================================================
    The templates for decorating fixtures with the metadata needed to write out the individual asserts
    ==================================================================================================
    -->

    <!-- 
        Decorate an element in a FHIR fixture with the following information from the StructureDefinition:
        - nts:dataType: data type as string
        - nts:max: max cardinality as string, may be '*' or 'UNK'
        - nts:elementPath: the path of the element within its resource or complex data type StructureDefinition (as found in
          ElementDefinition.path)
        - nts:fhirPath: the FHIRPath expression to the element in the resource StructureDefintion. This expression
          might use '$_EXP' as a placeholder for selecting a specific instance of a repeating or polymorphic element.
        - nts:descriptionPath: the path to the element in the resource StructureDefintion

        The following parameters are recognized:
        - structureDefintion: the StructureDefinition corresponding with the fixture
        - parent*: the corresponding nts:* variables of the parent element (only if this template is called recursively)
        - parentResourceElementPath: the parent path in the resource StructureDefinition (only if this template is
          called recursively, usually the same as parentElementPath)
        - parentResourceDataType: the data type of the parent path in the resource StructureDefinition (only if this
          template is called recursively)
    -->
    <xsl:template match="f:*" mode="generateContentAsserts.addMetaData">
        <xsl:param name="structureDefinition" required="yes" tunnel="yes"/>
        <xsl:param name="parentElementPath" required="no"/>
        <xsl:param name="parentFhirPath" required="no"/>
        <xsl:param name="parentDescriptionPath" required="no"/>
        <xsl:param name="parentDataType" required="no"/>
        <xsl:param name="parentResourceElementPath" required="no"/>
        <xsl:param name="parentResourceDataType" required="no"/>
        
        <!-- We need to assume what would be the polymorphicElementPath if the element is indeed polymorphic -->
        <xsl:variable name="polymorphicElementPath">
            <xsl:choose>
                <xsl:when test="string-length($parentResourceDataType) gt 0">
                    <xsl:value-of select="replace(concat($parentElementPath, '.', nf:get-element-base(local-name()), '[x]'), $parentResourceElementPath, $parentResourceDataType,'q')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($parentElementPath, '.',  nf:get-element-base(local-name()), '[x]')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- If datatype, overrule structureDefinition -->
        <xsl:variable name="structureDefinition">
            <xsl:choose>
                <xsl:when test="$parentResourceDataType = $complexDataTypes and not($parentResourceDataType = 'Extension')">
                    <xsl:copy-of select="document(concat($libPath, lower-case($fhirVersion), '/', $parentResourceDataType, '.xml'))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="$structureDefinition"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- Determine this once and store in variable -->
        <xsl:variable name="isPolymorphic">
            <xsl:choose>
                <xsl:when test="$structureDefinition/f:StructureDefinition/f:snapshot/f:element/@id = $polymorphicElementPath or parent::f:extension or parent::f:modifierExtension">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="false()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="elementPath">
            <xsl:choose>
                <!-- Base resource -->
                <xsl:when test="string-length($parentElementPath) = 0">
                    <xsl:value-of select="local-name()"/>
                </xsl:when>
                <!-- Complex datatypes aren't included in snapshot, so we find them this way -->
                <xsl:when test="$parentResourceDataType = $complexDataTypes">
                    <!--<xsl:variable name="head">
                        <xsl:variable name="regexReplace">
                            <xsl:call-template name="substring-before-last">
                                <xsl:with-param name="input" select="concat($parentElementPath, '.', local-name())"/>
                                <xsl:with-param name="substr" select="'.'"/>
                            </xsl:call-template>
                        </xsl:variable>
                        <xsl:value-of select="replace($regexReplace,'((\]|\[))','\\$1')"/>
                    </xsl:variable>-->
                    <xsl:value-of select="replace(concat($parentElementPath, '.', local-name()), $parentResourceElementPath, $parentResourceDataType,'q')"/>
                </xsl:when>
                <xsl:when test="self::f:extension or self::f:modifierExtension">Extension</xsl:when>
                <xsl:when test="$isPolymorphic = true()">
                    <xsl:value-of select="$polymorphicElementPath"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($parentElementPath, '.', local-name())"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="polymorphicDataType" select="nf:datatype-case(substring-after(local-name(), nf:get-element-base(local-name())))"/>
        
        <!-- Extract the relevant ElementDefinition from the StructureDefinition -->
        <xsl:variable name="elementDefinition">
            <xsl:choose>
                <xsl:when test="self::f:extension or self::f:modifierExtension or parent::f:extension or parent::f:modifierExtension">
                    <!-- We don't need one -->
                </xsl:when>
                <xsl:when test="$structureDefinition/f:StructureDefinition/f:snapshot/f:element/@id = $elementPath">
                    <xsl:copy-of select="$structureDefinition/f:StructureDefinition/f:snapshot/f:element[@id = $elementPath]"/>
                </xsl:when>
                <xsl:when test="$isPolymorphic = true()">
                    <xsl:copy-of select="$structureDefinition/f:StructureDefinition/f:snapshot/f:element[@id = $polymorphicElementPath]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message>Could not find ElementDefinition <xsl:value-of select="$elementPath"/></xsl:message>
                    <xsl:message select="$parentResourceDataType"/>
                    <xsl:message select="$parentDataType"/>
                    <xsl:message select="concat($structureDefinition/f:StructureDefinition/f:id/@value,'')"/>
                    <xsl:message select="$isPolymorphic"/>
                    <xsl:message select="$polymorphicElementPath"/>
                    <xsl:message select="$parentResourceElementPath"/>
                    <xsl:message select="$parentElementPath"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="dataType">
            <xsl:choose>
                <xsl:when test="self::f:extension or self::f:modifierExtension">Extension</xsl:when>
                <xsl:when test="parent::f:extension or parent::f:modifierExtension">
                    <xsl:value-of select="$polymorphicDataType"/>
                </xsl:when>
                <xsl:when test="$elementDefinition/f:element/f:type/f:code/@value">
                    <xsl:choose>
                        <xsl:when test="count(distinct-values($elementDefinition/f:element/f:type/f:code/@value)) gt 1">
                            <xsl:value-of select="distinct-values($elementDefinition/f:element/f:type/f:code/@value[lower-case(.) = lower-case($polymorphicDataType)])"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="distinct-values($elementDefinition/f:element/f:type/f:code/@value)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$structureDefinition/f:StructureDefinition[f:kind/@value = 'resource'][f:type/@value = $elementPath]">
                    <!-- Suppress message for base resource -->
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message>Could not find datatype <xsl:value-of select="$elementPath"/></xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="max">
            <xsl:choose>
                <xsl:when test="$elementDefinition/f:element/f:max/@value">
                    <xsl:value-of select="$elementDefinition/f:element/f:max/@value"/>
                </xsl:when>
                <xsl:when test="self::f:extension or self::f:modifierExtension">
                    <xsl:variable name="url" select="@url"/>
                    <xsl:choose>
                        <xsl:when test="preceding-sibling::*[@url = $url] or following-sibling::*[@url = $url]">
                            <xsl:value-of select="'*'"/>
                        </xsl:when>
                        <xsl:otherwise>UNK</xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="parent::f:extension or parent::f:modifierExtension">1</xsl:when>
                <xsl:otherwise>
                    <xsl:message>Could not find max cardinality - <xsl:value-of select="$elementPath"/></xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="fhirPath">
            <xsl:choose>
                <xsl:when test="string-length($parentFhirPath) = 0">
                    <xsl:value-of select="local-name()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="addition">
                        <xsl:choose>
                            <xsl:when test="self::f:extension">
                                <xsl:value-of select="concat(local-name(), '(''', @url, ''')')"/>
                            </xsl:when>
                            <xsl:when test="self::f:modifierExtension">
                                <xsl:value-of select="concat(local-name(), '.where(url = ''', @url, ''')')"/>
                            </xsl:when>
                            <xsl:when test="$isPolymorphic = true() and not($dataType = 'Extension')">
                                <xsl:value-of select="concat(nf:get-element-base(local-name()), '.ofType(', $dataType, ')')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="local-name()"/>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:if test="$max = '*'">
                            <xsl:value-of select="'.where({$_EXPR})'"/>
                        </xsl:if>
                    </xsl:variable>
                    
                    <xsl:choose>
                        <xsl:when test="contains($parentFhirPath, '{$_EXPR}')">
                            <xsl:variable name="addition">
                                <xsl:choose>
                                    <xsl:when test="contains($addition, '{$_EXPR}')">
                                        <xsl:value-of select="$addition"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="concat($addition, '.{$_EXPR}')"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <xsl:value-of select="replace($parentFhirPath, '{$_EXPR}', $addition, 'q')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat($parentFhirPath, '.', $addition)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="descriptionPath">
            <xsl:choose>
                <xsl:when test="string-length($parentDescriptionPath) = 0">
                    <xsl:value-of select="local-name()"/>
                </xsl:when>
                <!-- Leaving this here for refactoring purposes, should be improved -->
                <xsl:when test="self::f:extension or self::f:modifierExtension">
                    <xsl:value-of select="concat($parentDescriptionPath, '.', local-name(), '(''', @url, ''')')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($parentDescriptionPath, '.', local-name())"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test="$dataType = 'Identifier' and preceding-sibling::*[local-name() = fn:current()/local-name()]">
                <xsl:message>Double Identifier detected: <xsl:value-of select="$elementPath"/> - Please check if this is a specific use case or not. If yes, it should be added to generateAsserts</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@*" mode="#current"/>
                    <xsl:attribute name="nts:dataType" select="$dataType"/>
                    <xsl:attribute name="nts:max" select="$max"/>
                    <xsl:attribute name="nts:elementPath" select="$elementPath"/>
                    <xsl:attribute name="nts:fhirPath" select="$fhirPath"/>
                    <xsl:attribute name="nts:descriptionPath" select="$descriptionPath"/>
                    
                    <xsl:if test="not($dataType = 'Narrative')">
                        <xsl:apply-templates select="node()" mode="#current">
                            <xsl:with-param name="parentElementPath" select="$elementPath"/>
                            <xsl:with-param name="parentFhirPath" select="$fhirPath"/>
                            <xsl:with-param name="parentDescriptionPath" select="$descriptionPath"/>
                            <xsl:with-param name="parentDataType" select="$dataType"/>
                            <xsl:with-param name="parentResourceElementPath">
                                <xsl:choose>
                                    <xsl:when test="$dataType = $complexDataTypes">
                                        <xsl:value-of select="$elementPath"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="$parentElementPath"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:with-param>
                            <xsl:with-param name="parentResourceDataType">
                                <xsl:choose>
                                    <xsl:when test="$dataType = $complexDataTypes">
                                        <xsl:value-of select="$dataType"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="$parentDataType"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:with-param>
                        </xsl:apply-templates>
                    </xsl:if>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="node()|@*" mode="generateContentAsserts.addMetaData">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!--
    ========================================================
    The templates for writing out the actual content asserts
    ========================================================
    -->

    <!--
    Output one or more TestScript asserts for each element encountered in the fixture.
    - resourceIdExpression: the expression to select the resource to check (aligns with nts:contentAsserts@expression
      in the relevant scenarios).
    - parentLabel: the label of the overarching test.
    - skipExtensions: if true, extension setting will be skipped. TODO: make this parameter available from the
      public interface.
    -->
    <xsl:template match="f:*" mode="generateContentAsserts.addAsserts">
        <xsl:param name="operationType" tunnel="yes"/>
        <xsl:param name="resourceType" tunnel="yes"/>
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="resourceIdExpression" tunnel="yes"/>
        <xsl:param name="parentLabel" required="yes"/>
        <xsl:param name="skipExtensions" select="false()"/>
        
        <xsl:variable name="parentFhirPath" select="parent::*/@nts:fhirPath"/>
        <xsl:variable name="fhirPath" select="@nts:fhirPath"/>
        
        <xsl:variable name="expressionBase">
            <xsl:choose>
                <xsl:when test="$operationType = 'read'">
                    <xsl:value-of select="concat($resourceType, $resourceIdExpression)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('Bundle.entry.resource.ofType(', $resourceType, ')',$resourceIdExpression)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="dataType" select="@nts:dataType"/>
        
        <xsl:if test="not($dataType = 'Narrative')">
            <!-- Generate (part of) expression based on data type -->
            <xsl:variable name="expression">
                <xsl:call-template name="_createLocalExpression">
                    <xsl:with-param name="topLevel" select="true()"/>
                    <xsl:with-param name="focusFhirPath" select="$parentFhirPath"/>
                    <xsl:with-param name="skipExtensions" select="$skipExtensions"/>
                </xsl:call-template>
            </xsl:variable>
            
            <xsl:variable name="label">
                <xsl:value-of select="$parentLabel"/>
                <xsl:text>-</xsl:text>
                <xsl:value-of select="(if ($skipExtensions = false()) then count(preceding-sibling::*[not(self::f:id)]) else count(f:extension|f:modifierExtension)) + (if (parent::*/@value) then 2 else 1) + (if (preceding-sibling::*/@nts:dataType = 'Narrative') then -1 else 0)"/>
            </xsl:variable>
                        
            <xsl:variable name="description">
                <xsl:call-template name="_createDescription">
                    <xsl:with-param name="topLevel" select="true()"/>
                    <xsl:with-param name="resourceTypeFocus" select="true()"/>
                    <xsl:with-param name="skipExtensions" select="$skipExtensions"/>
                </xsl:call-template>
                <!-- If there are two hyphens or more in label -->
                <xsl:if test="string-length($label) - string-length(translate($label, '-', '')) ge 2">
                    <xsl:value-of select="concat('. This assert checks only one child. Assert ', $parentLabel, ' checks if all children are present in the same parent')"/>
                </xsl:if>
                <xsl:if test="($dataType = $containerTypes and count(*) gt 1) or ((f:extension or f:modifierExtension) and $skipExtensions = false())">
                    <xsl:value-of select="'. This assert checks if all children exist (if applicable with their specific values) and if they are present within one element. Following asserts check if individual children exist to help you debug if this assert fails'"/>
                </xsl:if>
                <xsl:if test="$dataType = 'string'">
                    <xsl:value-of select="'. This assert only checks existence of a value, because string comparisons can have many possible caveats'"/>
                </xsl:if>
            </xsl:variable>
            
            <xsl:if test="string-length($expression) gt 0">
                <xsl:call-template name="createAssert">
                    <xsl:with-param name="description" select="concat('Contains ', $description)"/>
                    <xsl:with-param name="expression">
                        <xsl:choose>
                            <xsl:when test="contains($parentFhirPath, '{$_EXPR}')">
                                <xsl:value-of select="concat($expressionBase,substring-after(replace($parentFhirPath, '{$_EXPR}', normalize-space($expression), 'q'), $resourceType),'.exists()')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat($expressionBase,substring-after($parentFhirPath, $resourceType), '.', $expression)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="label" select="$label"/>
                    <xsl:with-param name="warningOnly">
                        <xsl:choose>
                            <!-- Impossible to determine if code-specification is required without accessing ConceptMaps, so putting them all on warningOnly for now -->
                            <xsl:when test="descendant-or-self::f:extension[@url = 'http://nictiz.nl/fhir/StructureDefinition/code-specification'] and $skipExtensions = false()">
                                <xsl:value-of select="true()"/>
                            </xsl:when>
                            <xsl:when test="$dataType = 'string'">
                                <xsl:value-of select="true()"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="false()"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:if>
            
            <xsl:if test="$dataType = 'dateTime'">
                <!-- Remomved everything here 2023-10-05 - because it just wasn't working properly. Compare some dates? Sure! But when T-dates, times and time zones are involved, there are too many caveats at the moment. -->
            </xsl:if>
            
            <xsl:if test="$dataType = 'Identifier'">
                <!-- System should not contain Nictiz OID or 'example-xis' url -->
            </xsl:if>
            
            <!-- For some elements, we want te create additional asserts -->        
            <xsl:if test="$dataType = $containerTypes and count(*) gt 1 or ((f:extension or f:modifierExtension) and $skipExtensions = false())">
                <xsl:if test="@value">
                    <xsl:variable name="expression">
                        <xsl:call-template name="_createLocalExpression">
                            <xsl:with-param name="topLevel" select="true()"/>
                            <xsl:with-param name="focusFhirPath" select="$parentFhirPath"/>
                            <xsl:with-param name="valueOnly" select="true()"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:variable name="description">
                        <xsl:value-of select="substring-after(@nts:descriptionPath, $resourceType)"/>
                        <xsl:text> </xsl:text>
                        <xsl:call-template name="_createDescriptionSimple"/>
                        <xsl:value-of select="concat('. This assert checks only one child. Assert ', $label, ' checks if all children are present in the same parent')"/>
                    </xsl:variable>
                    <xsl:call-template name="createAssert">
                        <xsl:with-param name="description" select="concat('Contains ', $description)"/>
                        <xsl:with-param name="expression">
                            <xsl:choose>
                                <xsl:when test="contains($parentFhirPath, '{$_EXPR}')">
                                    <xsl:value-of select="concat($expressionBase,substring-after(replace($parentFhirPath, '{$_EXPR}', normalize-space($expression), 'q'), $resourceType),'.exists()')"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat($expressionBase,substring-after($parentFhirPath, $resourceType), '.', $expression)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:with-param>
                        <xsl:with-param name="label" select="concat($label,'-1')"/>
                    </xsl:call-template>
                </xsl:if>
                <xsl:if test="$skipExtensions = false() and ((not(@value) and count(f:*) gt 1) or @value and f:*)">
                    <xsl:apply-templates select="f:extension|f:modifierExtension" mode="#current">
                        <xsl:with-param name="parentLabel" select="$label"/>
                    </xsl:apply-templates>
                </xsl:if>
                <xsl:choose>
                    <xsl:when test="$dataType = $containerTypes">
                        <xsl:apply-templates select="*[not(self::f:extension) and not(self::f:modifierExtension)]" mode="#current">
                            <xsl:with-param name="parentLabel" select="$label"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:when test="$skipExtensions = true()"/>
                    <xsl:when test="not(*[not(self::f:extension) and not(self::f:modifierExtension)])"/>
                    <xsl:otherwise>
                        <xsl:apply-templates select="." mode="#current">
                            <xsl:with-param name="parentLabel" select="$label"/>
                            <xsl:with-param name="skipExtensions" select="true()"/>
                        </xsl:apply-templates>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:if>
        
    </xsl:template>
    
    <!--
        Create a TestScript.assert element based on the input.
    -->
    <xsl:template name="createAssert">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="description" required="yes"/>
        <xsl:param name="expression" required="yes"/>
        <xsl:param name="label"/>
        <xsl:param name="warningOnly" select="false()"/>
        <xsl:param name="stopTestOnFail" select="false()"/>
        
        <action>
            <assert>
                <!-- False is the default of the NTS process, so we do not have to add anything in that case -->
                <xsl:if test="$stopTestOnFail = true()">
                    <xsl:attribute name="nts:stopTestOnFail">true</xsl:attribute>
                </xsl:if>
                <xsl:if test="fn:string-length($label) gt 0">
                    <label value="{$label}"/>
                </xsl:if>
                <description value="{$description}"/>
                <!-- Should be edited based on scenario probably, leaving it fixed on 'response' for now -->
                <direction>
                    <xsl:attribute name="value">
                        <xsl:choose>
                            <xsl:when test="$scenario = 'client'">
                                <xsl:value-of select="'request'"/>
                            </xsl:when>
                            <xsl:when test="$scenario = 'server'">
                                <xsl:value-of select="'response'"/>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:attribute>
                </direction>
                <expression value="{$expression}"/>
                <!-- False is the default of the NTS process, so we do not have to add anything in that case -->
                <xsl:if test="$warningOnly = true()">
                    <warningOnly value="true"/>
                </xsl:if>
            </assert>
        </action>
    </xsl:template>
    
    <!-- Create a localized part of the FHIRPath expression for the content assert. This can be a recursive process
         which includes this template and the helper templates _createExpressionSimple and _createExtensionExpression.
         - topLevel: if true, the result will be treated as a complete expression and not just a part. Top level
           expressions that don't check for something specific will be appended with FHIRPath .exists().
         - focusFhirPath: The FHIRPath expression selecting the element where the assert needs to occur on. Might
           contain the '$_EXP' placeholder. Note that this is is not part of the final output.
         - skipExtensions: if true, extension setting will be skipped. TODO: make this parameter available from the
           public interface.
         - valueOnly: Create an expression to only check the concrete value or existence of the element. Only relevant
           for top level expressions.
    -->
    <xsl:template name="_createLocalExpression">
        <xsl:param name="topLevel" select="false()"/>
        <xsl:param name="focusFhirPath" required="yes"/>
        <xsl:param name="skipExtensions" select="false()"/>
        <xsl:param name="valueOnly" select="false()"/>
        
        <xsl:variable name="fhirPath" select="@nts:fhirPath"/>
        <xsl:variable name="dataType" select="@nts:dataType"/>
        <xsl:variable name="parentDataType" select="parent::f:*/@nts:dataType"/>
        
        <!-- The 'local' part of the expression, which is later combined with $addition to create the FHIRpath expression. -->
        <xsl:variable name="local">
            <xsl:choose>
                <xsl:when test="string-length(substring-after($fhirPath, $focusFhirPath)) gt 0">
                    <xsl:value-of select="substring-after($fhirPath, concat($focusFhirPath, '.'))"/>
                </xsl:when>
                <xsl:when test="not($focusFhirPath = $fhirPath) and contains($focusFhirPath, '{$_EXPR}')">
                    <xsl:variable name="escapeChars" select="replace($focusFhirPath, '([.()\\])', '\\$1')"/>
                    <xsl:variable name="regex" select="replace($escapeChars, '{$_EXPR}', '(.+)', 'q')"/>
                    <xsl:value-of select="replace($fhirPath, $regex, '$1')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$fhirPath"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="addition">
            <!-- We need to make a separation between elements without children (simple data types) and with children (simple data types with extensions and complex data types). Expression for simple data types without children are ... simpler -->
            <xsl:choose>
                <xsl:when test="$dataType = 'id' or ($dataType = 'http://hl7.org/fhirpath/System.String' and self::f:id)">
                    <!-- An assert for Resource.id has been made earlier in the process because it is essential. So here we do nothing -->
                    <!-- For some reason, the official data type of .id in R4 is this System.String thing -->
                </xsl:when>
                <xsl:when test="(($skipExtensions = false() and f:*) or ($skipExtensions = true() and f:*[not(self::f:extension) and not(self::f:modifierExtension)])) and $valueOnly = false()">
                    <xsl:choose>
                        <!-- When simple data type (may or may not have @value) contains extension -->
                        <xsl:when test="$dataType = $simpleDataTypes and f:extension and $skipExtensions = false()">
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>.where(</xsl:text>
                            </xsl:if>
                            <xsl:if test="@value">
                                <xsl:call-template name="_createExpressionSimple">
                                    <xsl:with-param name="includeThis" select="true()"/>
                                </xsl:call-template>
                                <xsl:text> and </xsl:text>
                            </xsl:if>
                            <xsl:for-each select="*">
                                <xsl:call-template name="_createLocalExpression">
                                    <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                                </xsl:call-template>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>)</xsl:text>
                            </xsl:if>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Attachment'">
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:call-template name="_createExtensionExpression">
                                    <xsl:with-param name="fhirPath" select="$fhirPath"/>
                                </xsl:call-template>
                            </xsl:if>
                            <xsl:text>.where(</xsl:text>
                            <xsl:for-each select="*[self::f:contentType or self::f:language]">
                                <xsl:call-template name="_createLocalExpression">
                                    <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                                </xsl:call-template>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                            <xsl:if test="f:data or f:url">
                                <xsl:if test="*[self::f:contentType or self::f:language]">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                                <xsl:if test="*[not(self::f:data) and not(self::f:url)]">
                                    <xsl:text>(</xsl:text>
                                </xsl:if>
                                <xsl:text>data or url</xsl:text>
                                <xsl:if test="*[not(self::f:data) and not(self::f:url)]">
                                    <xsl:text>)</xsl:text>
                                </xsl:if>
                                <xsl:if test="*[not(self::f:contentType) and not(self::f:language) and not(self::f:data) and not(self::f:url)]">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:if>
                            <xsl:for-each select="*[not(self::f:contentType) and not(self::f:language) and not(self::f:data) and not(self::f:url)]">
                                <xsl:call-template name="_createLocalExpression">
                                    <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                                </xsl:call-template>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                            <xsl:text>)</xsl:text>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Identifier'">
                            <xsl:if test="f:extension">
                                <xsl:message select="concat('UNHANDLED EXTENSION EXPRESSION: ', $fhirPath, ' - ',$dataType)"/>
                            </xsl:if>
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>.where(</xsl:text>
                            </xsl:if>
                            <xsl:choose>
                                <xsl:when test="f:system">system</xsl:when>
                                <xsl:when test="f:type">type</xsl:when>
                            </xsl:choose>
                            <xsl:text> and value</xsl:text>
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>)</xsl:text>
                            </xsl:if>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Reference'">
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>.where(</xsl:text>
                            </xsl:if>
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:call-template name="_createExtensionExpression">
                                    <xsl:with-param name="fhirPath" select="$fhirPath"/>
                                </xsl:call-template>
                                <xsl:if test="f:extension|f:modifierExtension"> and </xsl:if>
                            </xsl:if>
                            <!-- Check if (reference OR identifier) and display exist -->
                            <xsl:text>(reference</xsl:text>
                            <xsl:text> or identifier</xsl:text>
                            <xsl:text>) and </xsl:text>
                            <xsl:if test="$fhirPath = 'R4'">
                                <xsl:text>type and </xsl:text>
                            </xsl:if>
                            <xsl:text>display</xsl:text>
                            <xsl:if test="not(@nts:max = '*')">
                                <xsl:text>)</xsl:text>
                            </xsl:if>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Narrative' and f:status/@value = ('extensions','generated')">
                            <!-- Narrative isn't always present in fixtures. If not present, it is generated at a later stage. We should find a way to always add this assert. -->
                            <xsl:text> </xsl:text>
                        </xsl:when>
                        <xsl:when test="$dataType = ('Address','Annotation','BackboneElement', 'Element','CodeableConcept','Coding','ContactPoint','Dosage','Duration','Extension','HumanName','Meta','Period','Quantity','Range','Ratio','Timing')">
                            <!-- If there are multiple children, we need a where statement -->
                            <xsl:if test="count(f:*) gt 1 and not(@nts:max = '*')">
                                <xsl:text>where(</xsl:text>
                            </xsl:if>
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:for-each select="f:extension|f:modifierExtension">
                                    <xsl:call-template name="_createLocalExpression">
                                        <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                                    </xsl:call-template>
                                    <xsl:if test="not(position() = last()) or (position() = last() and following-sibling::f:*)">
                                        <xsl:text> and </xsl:text>
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:if>
                            <xsl:for-each select="*[not(self::f:extension) and not(self::f:modifierExtension)]">
                                <xsl:call-template name="_createLocalExpression">
                                    <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                                </xsl:call-template>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                            <xsl:if test="count(f:*) gt 1 and not(@nts:max = '*')">
                                <xsl:text>)</xsl:text>
                            </xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:message select="concat('TODO EXPRESSION: ', $fhirPath, ' - ',$dataType)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="_createExpressionSimple">
                        <xsl:with-param name="includeThis">
                            <xsl:choose>
                                <xsl:when test="@nts:max = '*'">
                                    <xsl:value-of select="true()"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="false()"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="expression">
            <xsl:choose>
                <!-- When local contains {$_EXPR}, we want to insert addition there -->
                <xsl:when test="contains($local, '{$_EXPR}')">
                    <xsl:variable name="regex">
                        <xsl:choose>
                            <xsl:when test="string-length(fn:normalize-space($addition)) = 0 and contains($local, '.where({$_EXPR})')">
                                <xsl:value-of select="'.where({$_EXPR})'"/>
                            </xsl:when>
                            <xsl:when test="starts-with($addition, ' ') or starts-with($addition, '.') and contains($local, '.{$_EXPR}')">
                                <xsl:value-of select="'.{$_EXPR}'"/>
                            </xsl:when>
                            <xsl:when test="starts-with($addition, '.where(') and contains($local, '.where({$_EXPR})')">
                                <xsl:value-of select="'.where({$_EXPR})'"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="'{$_EXPR}'"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="addition">
                        <xsl:choose>
                            <xsl:when test="string-length(normalize-space($addition)) gt 0">
                                <xsl:value-of select="$addition"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="normalize-space($addition)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="replace($local, $regex, $addition, 'q')"/>
                </xsl:when>
                <xsl:when test="matches($local, 'where\([^(]+(\))+$') and not(matches($local, 'modifierExtension.where\(url = [^(]+(\))+$'))">
                    <!-- Escape dollar signs ($this) -->
                    <xsl:variable name="regexAddition" select="replace($addition, '$', '\$', 'q')"/>
                    <xsl:value-of select="replace($local, '(\))+$', concat($regexAddition, '$1'))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$local"/>
                    <!-- Add a dot if addition doesn't start with a space or dot -->
                    <xsl:if test="not(starts-with($addition, ' ')) and not(starts-with($addition, '.'))">
                        <xsl:text>.</xsl:text>
                    </xsl:if>
                    <xsl:choose>
                        <!-- If addition contains something other then space, we assume spaces are important -->
                        <xsl:when test="string-length(normalize-space($addition)) gt 0">
                            <xsl:value-of select="$addition"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="normalize-space($addition)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:if test="string-length($addition) gt 0">
            <xsl:value-of select="$expression"/>

            <!-- For toplevel expressions that don't actually check anything, add the default behavior of .exists() -->
            <xsl:if test="$topLevel = true() and not(matches($expression, ' (=|~) (true|false|''[^'']+''|[\d.]+)$')) and not(ends-with($expression, '.exists()')) and not(ends-with($expression, '.hasValue()'))">
                <xsl:text>.exists()</xsl:text>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
    <!-- Create the FHIRPath assert expression for a simple data type. This template contains the domain logic for
         handling the different simple data types.
         - dataType: the data type for which the expression is created
         - parentDataType: the data type of the parent
         - includeThis: whether to include '$this' at the start of expression
    -->
    <xsl:template name="_createExpressionSimple">
        <xsl:param name="dataType" select="@nts:dataType"/>
        <xsl:param name="parentDataType" select="parent::f:*/@nts:dataType"/>
        <xsl:param name="includeThis" select="false()"/>
        
        <xsl:variable name="expression">
            <xsl:choose>
                <xsl:when test="$parentDataType = 'Attachment'">
                    <!-- In Attachment, there is hardly anything that we can reliably check for more than existance, so we do nothing here. -->
                    <xsl:text> </xsl:text>
                </xsl:when>
                <xsl:when test="$dataType = ('boolean', 'decimal','integer')">
                    <xsl:if test="$includeThis = true()">
                        <xsl:text>$this</xsl:text>
                    </xsl:if>
                    <xsl:value-of select="concat(' = ', @value)"/>
                </xsl:when>
                <xsl:when test="$dataType = 'string' and $parentDataType = ('Coding','Quantity')">
                    <!-- This is .display (in Coding) or .unit (in Quantity), so we only check for existence. No need to add .exists() -->
                    <xsl:text> </xsl:text>
                </xsl:when>
                <xsl:when test="$dataType = 'string'">
                    <!--<!-\- '~' (equivalence) ignores case and whitespace. replace('.', '') removes dot and comma (or other characters - hyphens perhaps?). Or should we be allowed to define overrides in our NTS-script? -\->
                    <xsl:if test="$includeThis = true()">
                        <xsl:text>$this</xsl:text>
                    </xsl:if>
                    <!-\- Please be aware that for regex reasons, the hyphen should be either first or last in this string -\->
                    <xsl:variable name="replaceChars" select="'[ .,_-]+'"/>
                    <xsl:value-of select="concat('.replaceMatches(''', $replaceChars, ''', '' '') ~ ''', replace(@value, $replaceChars, ' '), '''')"/>-->
                    <xsl:if test="$includeThis = true()">
                        <xsl:text>$this</xsl:text>
                    </xsl:if>
                    <xsl:text>.hasValue()</xsl:text>
                </xsl:when>
                <xsl:when test="$dataType = ('dateTime','date','instant')">
                    <!-- For now we only check if date or dateTime exist -->
                    <xsl:text> </xsl:text>
                </xsl:when>
                <xsl:when test="$dataType = 'code' and $parentDataType = 'Quantity'">
                    <xsl:if test="$includeThis = true()">
                        <xsl:text>$this</xsl:text>
                    </xsl:if>
                    <!-- .code can contain UCUM parentheses -->
                    <xsl:choose>
                        <xsl:when test="contains(@value, '{') and contains(@value, '}') ">
                            <xsl:text>.matches('^</xsl:text>
                            <xsl:analyze-string select="@value" regex="\{{.*\}}">
                                <xsl:matching-substring>
                                    <xsl:text>\\{.+\\}</xsl:text>
                                </xsl:matching-substring>
                                <xsl:non-matching-substring>
                                    <xsl:value-of select="."/>
                                </xsl:non-matching-substring>
                            </xsl:analyze-string>
                            <xsl:text>$')</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat(' = ''', nf:escape-string(@value), '''')"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$dataType = 'code' or ($dataType = ('canonical', 'uri') and $parentDataType = ('Coding', 'Meta', 'Quantity'))">
                    <!-- For uri's in Coding and Quantity (.system) or uri/canonical in Meta (.profile) we want an exact match. I can imagine that in some situations we want to only check for existance. -->
                    <xsl:if test="$includeThis = true()">
                        <xsl:text>$this</xsl:text>
                    </xsl:if>
                    <xsl:value-of select="concat(' = ''', @value, '''')"/>
                </xsl:when>
                <xsl:when test="$dataType = 'uri'">
                    <!-- For other uri's we assume there doesn't have to be an exact match. -->
                    <xsl:text> </xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message select="concat('TODO SIMPLE EXPRESSION: ',local-name(), ' - ',$dataType)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:value-of select="$expression"/>
    </xsl:template>
    
    <xsl:template name="_createExtensionExpression">
        <xsl:param name="fhirPath" required="yes"/>
        
        <xsl:if test="f:extension">
            <xsl:for-each select="f:extension">
                <xsl:call-template name="_createLocalExpression">
                    <xsl:with-param name="focusFhirPath" select="parent::f:*/@nts:fhirPath"/>
                </xsl:call-template>
                <xsl:if test="not(position() = last())">
                    <xsl:text> and </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <!-- Create (part of) the description for the content assert. This can be a recursive process which includes this
         template and the helper templates _createDescriptionSimple and _createExtensionDescription.-->
    <xsl:template name="_createDescription">
        <xsl:param name="resourceType" tunnel="yes"/>
        <!-- If true, the resource type is the focus of the description -->
        <xsl:param name="resourceTypeFocus" select="false()"/>
        <xsl:param name="skipExtensions" select="false()"/>
        <xsl:param name="topLevel" select="false()"/>
        
        <xsl:variable name="parentDescriptionPath" select="parent::f:*/@nts:descriptionPath"/>
        <xsl:variable name="descriptionPath" select="@nts:descriptionPath"/>
        <xsl:variable name="parentDataType" select="parent::f:*/@nts:dataType"/>
        <xsl:variable name="dataType" select="@nts:dataType"/>
        
        <xsl:variable name="descriptionPrefix">
            <xsl:choose>
                <xsl:when test="$resourceTypeFocus = true()">
                    <xsl:value-of select="substring-after($descriptionPath, $resourceType)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="substring-after($descriptionPath, $parentDescriptionPath)"/>
                </xsl:otherwise>
                <!--<xsl:when test="string-length($parentDescriptionPath) gt 0">
                    <xsl:value-of select="substring-after($descriptionPath, $parentDescriptionPath)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="substring-after($descriptionPath, $resourceType)"/>
                </xsl:otherwise>-->
            </xsl:choose>
        </xsl:variable>
        
        <!-- Here for refactoring purposes -->
        <xsl:variable name="descriptionPrefix">
            <xsl:choose>
                <xsl:when test="matches($descriptionPrefix, '\(''[^''\(\)]*''\)$')">
                    <xsl:value-of select="replace($descriptionPrefix, '\(''[^''\(\)]*''\)$', '')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$descriptionPrefix"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="description">
            <!-- We need to make a separation between element without children (simple data types) and with children (simple data types with extensions and complex data types). Expression for simple data types without children are ... simpler -->
            <xsl:choose>
                <xsl:when test="$dataType = 'id' or ($dataType = 'http://hl7.org/fhirpath/System.String' and self::f:id)">
                    <!-- An assert for Resource.id has been made earlier in the process because it is essential. So here we do nothing -->
                    <!-- For some reason, the official data type of .id in R4 is this System.String thing -->
                </xsl:when>
                <xsl:when test="f:*">
                    <xsl:choose>
                        <xsl:when test="$dataType = $simpleDataTypes and f:extension and f:extension">
                            <xsl:if test="@value">
                                <xsl:call-template name="_createDescriptionSimple"/>
                                <xsl:text> and </xsl:text>
                            </xsl:if>
                            <xsl:text>with </xsl:text>
                            <xsl:for-each select="*">
                                <xsl:call-template name="_createDescription"/>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Attachment'">
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:call-template name="_createExtensionDescription"/>
                            </xsl:if>
                            <xsl:text>with </xsl:text>
                            <xsl:for-each select="*[self::f:contentType or self::f:language]">
                                <xsl:variable name="description">
                                    <xsl:call-template name="_createDescription"/>
                                </xsl:variable>
                                <xsl:if test="fn:string-length($description) gt 0">
                                    <xsl:value-of select="$description"/>
                                </xsl:if>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                            <xsl:if test="f:data or f:url">
                                <xsl:if test="*[self::f:contentType or self::f:language]">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                                <xsl:text>with either .data or .url</xsl:text>
                                <xsl:if test="*[not(self::f:contentType) and not(self::f:language) and not(self::f:data) and not(self::f:url)]">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:if>
                            <xsl:for-each select="*[not(self::f:contentType) and not(self::f:language) and not(self::f:data) and not(self::f:url)]">
                                <xsl:variable name="description">
                                    <xsl:call-template name="_createDescription"/>
                                </xsl:variable>
                                <xsl:if test="fn:string-length($description) gt 0">
                                    <xsl:value-of select="$description"/>
                                </xsl:if>
                                <xsl:if test="not(position() = last())">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Identifier'">
                            <xsl:if test="f:extension">
                                <xsl:message select="concat('UNHANDLED EXTENSION DESCRIPTION: ', $descriptionPath, ' - ',$dataType)"/>
                            </xsl:if>
                            <xsl:text>with .</xsl:text>
                            <xsl:choose>
                                <xsl:when test="f:system">system</xsl:when>
                                <xsl:when test="f:type">type</xsl:when>
                            </xsl:choose>
                            <xsl:text> and .value</xsl:text>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Reference'">
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:call-template name="_createExtensionDescription"/>
                            </xsl:if>
                            <xsl:text>with either .reference or .identifier and .display</xsl:text>
                        </xsl:when>
                        <xsl:when test="$dataType = 'Narrative' and f:status/@value = ('extensions','generated')">
                            <!-- Nothing to add -->
                            <xsl:text> </xsl:text>
                        </xsl:when>
                        <xsl:when test="$dataType = ('Address','Annotation','BackboneElement', 'Element','CodeableConcept','Coding','ContactPoint','Dosage','Duration','Extension','HumanName','Meta','Period','Quantity','Range','Ratio','Timing')">
                            <xsl:if test="$dataType = 'Extension'">
                                <xsl:value-of select="concat('with url ''', @url, ''' ')"/>
                            </xsl:if>
                            <xsl:text>with </xsl:text>
                            <xsl:if test="$skipExtensions = false()">
                                <xsl:for-each select="f:extension|f:modifierExtension">
                                    <xsl:variable name="description">
                                        <xsl:call-template name="_createDescription"/>
                                    </xsl:variable>
                                    <xsl:if test="fn:string-length($description) gt 0">
                                        <xsl:value-of select="$description"/>
                                    </xsl:if>
                                    <xsl:if test="not(position() = last()) or (position() = last() and following-sibling::f:*)">
                                        <xsl:text> and </xsl:text>
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:if>
                            <xsl:for-each select="*[not(self::f:extension) and not(self::f:modifierExtension)]">
                                <xsl:variable name="description">
                                    <xsl:call-template name="_createDescription"/>
                                </xsl:variable>
                                <xsl:if test="fn:string-length($description) gt 0">
                                    <xsl:value-of select="$description"/>
                                </xsl:if>
                                <xsl:if test="not(position() = last())">
                                    <xsl:if test="$topLevel = true() and $dataType = $containerTypes">
                                        <xsl:text>,</xsl:text>
                                    </xsl:if>
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:message select="concat('TODO DESCRIPTION: ', $descriptionPath, ' - ',$dataType)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="_createDescriptionSimple"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:if test="string-length($description) gt 0">
            <xsl:choose>
                <xsl:when test="string-length(normalize-space($description)) gt 0">
                    <xsl:value-of select="concat($descriptionPrefix, ' ',normalize-space($description))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($descriptionPrefix, normalize-space($description))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>
    
    <!-- Create the description part for a simple data type.
         - dataType: the data type for which the expression is created
         - parentDataType: the data type of the parent
    -->
    <xsl:template name="_createDescriptionSimple">
        <xsl:param name="dataType" select="@nts:dataType"/>
        <xsl:param name="parentDataType" select="parent::f:*/@nts:dataType"/>
        
        <xsl:choose>
            <xsl:when test="$parentDataType = 'Attachment'">
                <!-- In Attachment, there is hardly anything that we can reliably check for more than existance, so we do nothing here. -->
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$dataType = ('dateTime','date','instant') or ($dataType = 'string' and $parentDataType = ('Coding','Quantity'))">
                <!-- Nothing to be added, as we only check existance -->
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$dataType = 'string'">
                <xsl:text>with a value</xsl:text>
            </xsl:when>
            <xsl:when test="$dataType = ('boolean','decimal','integer'(:,'string':)) or ($dataType = ('uri','canonical') and $parentDataType = ('Coding','Meta','Quantity'))">
                <!-- For uri's in Coding and Quantity (.system) or Meta (.profile, uri is canonical in R4), we want an exact match. I can imagine that in some situations we want to only check for existance. -->
                <xsl:value-of select="concat('''', @value, '''')"/>
            </xsl:when>
            <xsl:when test="$dataType = 'uri'">
                <!-- Nothing to be added, as we only check existance -->
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$dataType = 'code'">
                <xsl:variable name="value" select="@value"/>
                <xsl:choose>
                    <xsl:when test="$parentDataType = 'Quantity' and contains($value, '{') and contains($value, '}') ">
                        <xsl:text>matching regex '^</xsl:text>
                        <xsl:analyze-string select="$value" regex="\{{\w*\}}">
                            <xsl:matching-substring>
                                <xsl:text>\\{.+\\}</xsl:text>
                            </xsl:matching-substring>
                            <xsl:non-matching-substring>
                                <xsl:value-of select="."/>
                            </xsl:non-matching-substring>
                        </xsl:analyze-string>
                        <xsl:text>$'</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('''', @value, '''')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat('TODO SIMPLE DESCRIPTION: ',$dataType)"/>
                <xsl:value-of select="'with ...'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="_createExtensionDescription">
        <xsl:if test="f:extension">
            <xsl:text>with </xsl:text>
            <xsl:for-each select="f:extension">
                <xsl:call-template name="_createDescription"/>
                <xsl:if test="position() = last()">
                    <xsl:text>,</xsl:text>
                </xsl:if>
                <xsl:text> and </xsl:text>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <!--
    =================
    Utility functions
    =================
    -->

    <xsl:function name="nf:get-element-base" as="xs:string">
        <xsl:param name="localName"/>
        <xsl:variable name="output">
            <xsl:analyze-string select="$localName" regex="^[a-zA-Z][a-z]+(([A-Z][a-z]+)+)">
                <xsl:matching-substring>
                    <xsl:value-of select="substring-before($localName, regex-group(1))"/>
                    <xsl:choose>
                        <xsl:when test="lower-case(regex-group(1)) = $dataTypesLower"/>
                        <xsl:otherwise>
                            <xsl:value-of select="nf:get-element-base(regex-group(1))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <!-- Always return _something_ -->
        <xsl:choose>
            <xsl:when test="string-length($output) gt 0">
                <xsl:value-of select="$output"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$localName"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="nf:datatype-case" as="xs:string">
        <xsl:param name="dataType"/>
        <xsl:choose>
            <xsl:when test="lower-case($dataType) = $simpleDataTypesLower">
                <xsl:choose>
                    <xsl:when test="lower-case($dataType) = 'datetime'">
                        <xsl:text>dateTime</xsl:text>
                    </xsl:when>
                    <xsl:when test="lower-case($dataType) = 'unsignedint'">
                        <xsl:text>unsignedInt</xsl:text>
                    </xsl:when>
                    <xsl:when test="lower-case($dataType) = 'positiveint'">
                        <xsl:text>positiveInt</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="lower-case($dataType)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$dataType"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- https://www.hl7.org/fhirpath/#string
        Escape	Character
        \'        Single-quote
        \"        Double-quote
        \`        Backtick
        \r        Carriage Return
        \n        Line Feed
        \t        Tab
        \f        Form Feed
        \\        Backslash
        \uXXXX    Unicode character, where XXXX is the hexadecimal representation of the character
        
        Does not handle form feed (not legal in xml) and 'any Unicode character'. 
    -->
    <xsl:function name="nf:escape-string" as="xs:string*">
        <xsl:param name="in" as="xs:string*"/>
        
        <xsl:for-each select="$in">
            <xsl:value-of select="replace($in, '(['&apos;`\r\n\t\\])', '\\$1')"/>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:template name="substring-before-last">
        <xsl:param name="input" />
        <xsl:param name="substr" />
        <xsl:if test="$substr and contains($input, $substr)">
            <xsl:variable name="temp" select="substring-after($input, $substr)" />
            <xsl:value-of select="substring-before($input, $substr)" />
            <xsl:if test="contains($temp, $substr)">
                <xsl:value-of select="$substr" />
                <xsl:call-template name="substring-before-last">
                    <xsl:with-param name="input" select="$temp" />
                    <xsl:with-param name="substr" select="$substr" />
                </xsl:call-template>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="analyzeTDate">
        <xsl:analyze-string select="@value" regex="\$\{{DATE, T, (Y|M|D), ([-]?)(\d+)\}}">
            <xsl:matching-substring>
                <xsl:choose>
                    <xsl:when test="regex-group(2) = '-'">- </xsl:when>
                    <xsl:otherwise>+ </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="regex-group(3)"/>
                <xsl:text> </xsl:text>
                <xsl:choose>
                    <xsl:when test="regex-group(1) = 'Y'">years</xsl:when>
                    <xsl:when test="regex-group(1) = 'M'">months</xsl:when>
                    <xsl:when test="regex-group(1) = 'D'">days</xsl:when>
                    <xsl:otherwise>
                        <xsl:message>Unkown T-date symbol: <xsl:value-of select="regex-group(1)"/></xsl:message>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
</xsl:stylesheet>