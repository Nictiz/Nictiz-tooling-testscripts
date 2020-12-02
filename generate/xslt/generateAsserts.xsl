<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:f="http://hl7.org/fhir"
    xmlns:nf="http://www.nictiz.nl/functions"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:template match="comment()" mode="#all" priority="1"/>
    
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- Fix to pretty print output - strip-space does not seem to function when being called from ANT -->
    <xsl:template match="text()[not(normalize-space(.))]" mode="#all"/>
    
    <!-- TO-DO/WISH LIST:
        
        - Handle T-dates relative to each other if no T-date variable is filled by the user 
        - Handle dateTimes and T-dates when determining uniqueness
        - Edit readme: "The `test` element where this element is added to will be duplicated"
        - Exclude specific parts of fixture when generating?
        
        - Better readable discriptions.
        - Refactor 'filter' mode in generateTestScript to be matched to separate 'filterTestScript.xsl'.
        
        - '_resources_not_copied' folder?
        - '_fixtures' folder not necessary, can also be '_resources' folder. Look at generateTestScript to see how filenames are resolved.
        - Handle client POST/PUTs that a server receives with minimumId instead of generating asserts. Depends on KT-198.
    -->
    
    <xsl:param name="referenceFolder" as="xs:string" required="yes"/>
    <xsl:param name="referenceGenerateFolder" as="xs:string" required="yes"/>
    <xsl:param name="scenario" as="xs:string" required="yes"/>
    
    <xsl:template match="node()|@*" mode="#all" priority="-1">
        <xsl:apply-templates select="node()|@*" mode="#current"/>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:copy>
            <xsl:apply-templates select="node()" mode="copy"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="f:TestScript/f:test[nts:generate-asserts-from]" mode="copy">
        <xsl:if test="not($scenario=('server','client'))">
            <xsl:message terminate="yes">Scenario value '<xsl:value-of select="$scenario"/>' not recognized. Should be one of 'server,client'.</xsl:message>
        </xsl:if>
        
        <!-- Get the operation code in a variable -->
        <xsl:variable name="operationCode" select="f:action/f:operation/f:type[f:system/@value = 'http://hl7.org/fhir/testscript-operation-codes']/f:code/@value"/>
        
        <xsl:choose>
            <!-- Make sure nts:generate-asserts-from is only added to tests where it is relevant, otherwise ignore. -->
            <!-- Edge case: when a server receives a POST or PUT, asserts are generated, but as it is supposed to send back the complete resource (with only resource.id added), perhaps using minimumId is more elegant. -->
            <xsl:when test="$scenario = 'server' or 
                $operationCode = ('batch','transaction','create','update','updateCreate')">
                
                <!-- If the operation code is not 'read', 'vread' or 'search', it is assumed the resources in the fixture are POST or PUT and therefore it is expected that all resources should be tested. -->
                <xsl:variable name="generateFromAll" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="not($operationCode = ('read', 'vread', 'search'))">
                            <xsl:value-of select="true()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="false()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- If the operation code is 'read', 'vread' or 'search', only the resources present in the operation resource and the _include parameter can be expected to be returned. -->
                <xsl:variable name="generateFromResources" as="element()*">
                    <xsl:if test="$operationCode = ('read', 'vread', 'search')">
                        <xsl:variable name="resource" select="f:action/f:operation/f:resource/@value"/>
                        <xsl:variable name="params" select="f:action/f:operation/f:params/@value"/>
                        <xsl:if test="$resource">
                            <resource name="{$resource}"/>
                        </xsl:if>
                        <xsl:if test="contains($params, '_include=')">
                            <xsl:variable name="afterInclude" select="substring-after($params, '_include=')"/>
                            <xsl:variable name="beforeAmp">
                                <xsl:choose>
                                    <xsl:when test="contains($afterInclude, '&amp;')">
                                        <xsl:value-of select="substring-before($afterInclude ,'&amp;')"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="$afterInclude"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <xsl:if test="not(substring-after($beforeAmp, concat($resource, ':')) = '')">
                                <xsl:variable name="includeParam" select="substring-after($beforeAmp, concat($resource, ':'))"/>
                                <xsl:choose>
                                    <xsl:when test="$includeParam = 'general-practitioner'">
                                        <resource name="Practitioner"/>
                                        <resource name="Organization"/>
                                    </xsl:when>
                                    <xsl:when test="$includeParam = 'medication'">
                                        <resource name="Medication"/>
                                    </xsl:when>
                                    <xsl:when test="$includeParam = 'related-target'">
                                        <resource name="Observation"/>
                                        <resource name="Sequence"/>
                                        <resource name="QuestionnaireResponse"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:message terminate="yes">Unknown _include search param: <xsl:value-of select="$includeParam"/></xsl:message>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>
                        </xsl:if>
                    </xsl:if>
                </xsl:variable>
                
                <!-- Create a fixture id based on the number of tests in the TestScript -->
                <xsl:variable name="fixtureId">
                    <xsl:variable name="testCount" select="count(preceding-sibling::f:test)+1"/>
                    <xsl:choose>
                        <xsl:when test="$scenario = 'client'">
                            <xsl:choose>
                                <xsl:when test="f:action/f:operation/f:requestId/@value">
                                    <xsl:value-of select="f:action/f:operation/f:requestId/@value"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('contentasserts-request-',$testCount)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$scenario = 'server'">
                            <xsl:choose>
                                <xsl:when test="f:action/f:operation/f:responseId/@value">
                                    <xsl:value-of select="f:action/f:operation/f:responseId/@value"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('contentasserts-response-',$testCount)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- If the resource is POST or PUT, generate asserts that check the request -->
                <xsl:variable name="direction">
                    <xsl:choose>
                        <xsl:when test="$generateFromAll">
                            <xsl:value-of select="'request'"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="'response'"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- Does the TestScript contain a T-variable? -->
                <xsl:variable name="TestScriptHasT">
                    <xsl:choose>
                        <xsl:when test="parent::f:Testscript/f:variable/f:name/@value='T'">
                            <xsl:value-of select="true()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="false()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- Get all resources, from Bundle if necessary -->
                <xsl:variable name="fixturesResources">
                    <!-- Get the normalized filenames of the fixtures to generate asserts from -->
                    <xsl:variable name="fixturesPathNormalized">
                        <xsl:for-each select="nts:generate-asserts-from">
                            <xsl:variable name="raw" select="@href"/>
                            <xsl:variable name="fixtureWithExtension">
                                <xsl:choose>
                                    <xsl:when test="ends-with($raw,'.xml')">
                                        <xsl:value-of select="$raw"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="concat($raw,'.xml')"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            
                            <xsl:choose>
                                <xsl:when test="doc-available(string-join(($referenceFolder, $fixtureWithExtension),'/'))">
                                    <nts:fixture href="{string-join(($referenceFolder, $fixtureWithExtension), '/')}"/>
                                </xsl:when>
                                <xsl:when test="doc-available(string-join(($referenceGenerateFolder,$fixtureWithExtension),'/'))">
                                    <nts:fixture href="{string-join(($referenceGenerateFolder, $fixtureWithExtension), '/')}"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:message terminate="yes">Fixture <xsl:value-of select="$fixtureWithExtension"/> not found.</xsl:message>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </xsl:variable>
                    
                    <xsl:for-each select="$fixturesPathNormalized/*">
                        <xsl:variable name="fixture" select="document(@href)"/>
                        <xsl:choose>
                            <xsl:when test="$fixture/f:Bundle">
                                <xsl:for-each select="$fixture/f:Bundle/f:entry/f:resource/f:*[$generateFromAll or local-name()=$generateFromResources/@name]">
                                    <xsl:copy-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:when test="$fixture/f:*[$generateFromAll or local-name()=$generateFromResources/@name]">
                                <xsl:for-each select="$fixture/f:*[$generateFromAll or local-name()=$generateFromResources/@name]">
                                    <xsl:copy-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                
                <!-- Copy the test as is -->
                <xsl:copy>
                    <xsl:apply-templates select="node()|@*" mode="copy">
                        <xsl:with-param name="fixtureId" tunnel="yes" select="$fixtureId"/>
                    </xsl:apply-templates>
                </xsl:copy>
                
                <!-- Add the generated asserts in a separate test without operation -->
                <test id="{@id}-content">
                    <name value="{f:name/@value} - Content checks"/>
                    <description value="Automatically generated checks to test if the contents of the message from the previous test adheres to the corresponding addendum"/>
                    
                    <!-- We want to determine the shortest FHIRpath expression possible to uniquely identify each resource within the set of fixtures. Evaluating only the individual elements generated in $generateAsserts does in some cases not lead to a unique excperssion, so we combine expressions to increase the chance of one of them being unique -->
                    
                    <!-- Evaluate all resources (add type, id and generate some sort of user friendly name) and, if there are multiple resources of a type, add expressionParts for all codes, integers and dateTimes. Each expressionPart has an elementId with only the expression to the element
                        Expected output:
                        <nts:generateAsserts>
                            <nts:resource type="Patient" id="XXX-Kesters" name="Patient-1">
                                <nts:expressionPart elementId="category.coding.code">category.coding.code.where($this = '282291009')</nts:expressionPart>
                                ...
                            </nts:resource>
                            <nts:resource type="..." id="..." name="..."/>
                        </nts:generateAsserts>
                    -->
                    <xsl:variable name="generateResource">
                        <nts:generateAsserts>
                            <xsl:for-each select="$fixturesResources/*">
                                <xsl:variable name="resourceType" select="local-name()"/>
                                <nts:resource type="{$resourceType}" id="{f:id/@value}">
                                    <xsl:attribute name="name">
                                        <xsl:call-template name="createResourceName"/>
                                    </xsl:attribute>
                                    <!-- If there are multiple resources of the same type, look for codes, integers and dateTimes to create parts of a FHIRpath expression that could be used to identify the resource -->
                                    <xsl:if test="not(count($fixturesResources/*[local-name() = $resourceType]) = 1)">
                                        <xsl:for-each select=".//@value[string(number(.)) != 'NaN' or parent::f:code][not(parent::f:versionId)][not(parent::f:value/parent::f:*[matches(local-name(), '[Ii]dentifier$')])]">
                                            <!-- only apply values that are numbers (integers) and codes. prevent ambiguity -->
                                            <xsl:variable name="elementId">
                                                <xsl:for-each select="ancestor::*[ancestor::*[local-name() = $resourceType]]">
                                                    <xsl:value-of select="nf:DTchoice(.)"/>
                                                    <xsl:if test="not(position() = last())">
                                                        <xsl:text>.</xsl:text>
                                                    </xsl:if>
                                                </xsl:for-each>
                                            </xsl:variable>
                                            <nts:expressionPart elementId="{$elementId}">
                                                <xsl:value-of select="$elementId"/>
                                                <xsl:choose>
                                                    <xsl:when test="parent::f:code">
                                                        <xsl:text>.where($this = '</xsl:text>
                                                        <xsl:value-of select="."/>
                                                        <xsl:text>')</xsl:text>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:text> = </xsl:text>
                                                        <xsl:value-of select="."/>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </nts:expressionPart>
                                        </xsl:for-each>
                                            <!--<xsl:for-each select=".//@value[starts-with(.,'${DATE, T')]">
                                                <xsl:variable name="elementId">
                                                    <xsl:for-each select="ancestor::*[ancestor::*[local-name()=$resourceType]]">
                                                        <xsl:value-of select="nf:DTchoice(.)"/>
                                                        <xsl:if test="not(position()=last())">
                                                            <xsl:text>.</xsl:text>
                                                        </xsl:if>
                                                    </xsl:for-each>
                                                </xsl:variable>
                                                <nts:expressionPart elementId="{$elementId}">
                                                    <xsl:value-of select="$elementId"/>
                                                    <xsl:text> = @</xsl:text>
                                                    <xsl:value-of select="."/>
                                                </nts:expressionPart>
                                            </xsl:for-each>-->
                                    </xsl:if>
                                </nts:resource>
                            </xsl:for-each>
                        </nts:generateAsserts>
                    </xsl:variable>
                    <!--<xsl:copy-of select="$generateResource"/>-->
                    
                    <xsl:variable name="generateResourceDoubleExpressions">
                        <nts:generateAsserts>
                            <xsl:for-each select="$generateResource/nts:generateAsserts/nts:resource">
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:for-each select="nts:expressionPart">
                                        <xsl:copy-of select="."/>
                                        <xsl:variable name="contents" select="text()"/>
                                        <xsl:variable name="elementId" select="@elementId"/>
                                        <xsl:for-each select="following-sibling::nts:expressionPart">
                                            <xsl:variable name="expression" select="concat($contents,' and ',./text())"/>
                                            <xsl:variable name="elementId2" select="@elementId"/>
                                            <nts:expressionPart elementId="{concat($elementId,'|',$elementId2)}">
                                                <xsl:value-of select="$expression"/>
                                            </nts:expressionPart>
                                        </xsl:for-each>
                                    </xsl:for-each>
                                </xsl:copy>
                            </xsl:for-each>
                        </nts:generateAsserts>
                    </xsl:variable>
                    <!--<xsl:copy-of select="$generateResourceDoubleExpressions"/>-->
                    
                    <!-- Determine which scenario for filtering is possible for each expressionPart and tag these by attribute 'unique':
                        1. If the expression with current elementId is present and unique for all resources of this type, flag it 'resource-type'
                        2. If this is the only expressionPart with this elementId within all resources of this e, flag it 'this-resource'
                        3. If the expression with current elementId is unique whenever it is present in resources of this type, flag it 'elementId'
                    -->
                    <xsl:variable name="generateIdentifyUniqueExpressionParts">
                        <nts:generateAsserts>
                            <xsl:for-each select="$generateResource/nts:generateAsserts/nts:resource">
                                <xsl:variable name="resourceType" select="@type"/>
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:for-each select="nts:expressionPart">
                                        <xsl:variable name="contents" select="./text()"/>
                                        <xsl:variable name="elementId" select="@elementId"/>
                                        <xsl:choose>
                                            <!-- scenario 1 -->
                                            <xsl:when test="count(ancestor::nts:generateAsserts/nts:resource[@type = $resourceType]) = count(distinct-values(ancestor::nts:generateAsserts/nts:resource[@type = $resourceType]/nts:expressionPart[@elementId = $elementId]/text()))">
                                                <xsl:copy>
                                                    <xsl:attribute name="unique">resource-type</xsl:attribute>
                                                    <xsl:copy-of select="@*|node()"/>
                                                </xsl:copy>
                                            </xsl:when>
                                            <!-- scenario 2 -->
                                            <xsl:when test="count(ancestor::nts:generateAsserts/nts:resource[@type = $resourceType]/nts:expressionPart[@elementId = $elementId]) = 1">
                                                <xsl:copy>
                                                    <xsl:attribute name="unique">this-resource</xsl:attribute>
                                                    <xsl:copy-of select="@*|node()"/>
                                                </xsl:copy>
                                            </xsl:when>
                                            <!-- scenario 3 -->
                                            <xsl:when test="count(ancestor::nts:generateAsserts/nts:resource[@type = $resourceType]//nts:expressionPart[@elementId = $elementId]) = count(distinct-values(ancestor::nts:generateAsserts/nts:resource[@type = $resourceType]/nts:expressionPart[@elementId = $elementId]/text()))">
                                                <xsl:copy>
                                                    <xsl:attribute name="unique">elementId</xsl:attribute>
                                                    <xsl:copy-of select="@*|node()"/>
                                                </xsl:copy>
                                            </xsl:when>
                                            <!-- otherwise, the expressionPart isn't 'unique enough' -->
                                            <xsl:otherwise>
                                                <xsl:copy-of select="."/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:for-each>
                                </xsl:copy>
                            </xsl:for-each>
                        </nts:generateAsserts>
                    </xsl:variable>
                    <!--<xsl:copy-of select="$generateIdentifyUniqueExpressionParts"/>-->
                    
                    <xsl:variable name="generateFilterExpressionParts">
                        <nts:generateAsserts>
                            <xsl:for-each select="$generateIdentifyUniqueExpressionParts/nts:generateAsserts/nts:resource">
                                <xsl:variable name="resourceType" select="@type"/>
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:choose>
                                        <xsl:when test="nts:expressionPart[@unique = 'resource-type']">
                                            <xsl:copy-of select="nts:expressionPart[@unique = 'resource-type'][1]"/>
                                        </xsl:when>
                                        <xsl:when test="nts:expressionPart[@unique = 'this-resource']">
                                            <xsl:copy-of select="nts:expressionPart[@unique = 'this-resource'][1]"/>
                                        </xsl:when>
                                        <xsl:when test="nts:expressionPart[@unique = 'elementId']">
                                            <xsl:copy-of select="nts:expressionPart[@unique = 'elementId'][1]"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="nts:expressionPart">
                                                <xsl:variable name="contents" select="./text()"/>
                                                <xsl:variable name="elementId" select="@elementId"/>
                                                <xsl:choose>
                                                    <!-- if the elementId contains '|' (e.g. it is generated by 'generateResourceDoubleExpressions'), filter it out -->
                                                    <xsl:when test="contains($elementId,'|')"/>
                                                    <!-- if the same expression is present in all resources of a type -->
                                                    <xsl:when test="count(ancestor::nts:idExpressions/nts:idExpression[@type = $resourceType]) = count(ancestor::nts:idExpressions/nts:idExpression[@type = $resourceType]/nts:*[text()=$contents])"/>
                                                    <xsl:otherwise>
                                                        <xsl:copy-of select="."/>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:copy>
                            </xsl:for-each>
                        </nts:generateAsserts>
                    </xsl:variable>
                    <!--<xsl:copy-of select="$generateFilterExpressionParts"/>-->
                    
                    <!-- Combine all expressionParts in one FHIRpath expression string -->
                    <xsl:variable name="generateCombinedExpression">
                        <nts:generateAsserts>
                            <xsl:for-each select="$generateFilterExpressionParts/nts:generateAsserts/nts:resource">
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:for-each select="nts:expressionPart">
                                        <xsl:value-of select="replace(., '[|]', ' and ')"/>
                                        <xsl:if test="not(position()=last())"> and </xsl:if>
                                    </xsl:for-each>
                                </xsl:copy>
                            </xsl:for-each>
                        </nts:generateAsserts>
                    </xsl:variable>
                    <!--<xsl:copy-of select="$generateCombinedExpression"/>-->
                    
                    <!-- For each resource -->
                    <xsl:for-each select="$generateCombinedExpression/nts:generateAsserts/nts:resource">
                        <xsl:variable name="resource" select="@resource"/>
                        
                        <!-- Check if the expression is really unique, as a backup -->
                        <xsl:variable name="is-unique">
                            <xsl:variable name="contents" select="text()"/>
                            <xsl:choose>
                                <xsl:when test="count($combinedIdExpressionParts/nts:idExpression[text() = $contents]) = 1 or count($combinedIdExpressionParts/nts:idExpression[@resource = $resource]) = 1">
                                    <xsl:value-of select="true()"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="false()"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:variable>
                        <xsl:variable name="position" select="count(preceding-sibling::nts:idExpression) + 1"/>
                        
                        <!-- Break if there is not a unique expression -->
                        <xsl:choose>
                            <xsl:when test="$is-unique = true()">
                                <!-- If the resource contains a T-variable, but the TestScript does not, add it -->
                                <!-- Should be added only once? -->
                                <xsl:if test="contains(text(), '${DATE, T') and $TestScriptHasT = false() and not(preceding-sibling::nts:idExpression[contains(text(), '${DATE, T')])">
                                    <variable>
                                        <name value="T"/>
                                        <defaultValue value="${{CURRENTDATE}}"/>
                                        <description value="Date that data and queries are expected to be relative to."/>
                                    </variable>
                                </xsl:if>
                                
                                <xsl:variable name="resourceExpression">
                                    <xsl:text>Bundle.entry.select(resource as </xsl:text>
                                    <xsl:value-of select="$resource"/>
                                    <xsl:text>)</xsl:text>
                                    <xsl:if test="count($combinedIdExpressionParts/nts:idExpression[@resource = $resource]) gt 1">
                                        <xsl:text>.where(</xsl:text>
                                        <xsl:value-of select="text()"/>
                                        <xsl:text>)</xsl:text>
                                    </xsl:if>
                                </xsl:variable>

                                <xsl:variable name="description">
                                    <xsl:text>Check if resource '</xsl:text>
                                    <xsl:value-of select="@name"/>
                                    <xsl:text>' selected with expression can be matched to exactly one resource.</xsl:text>
                                </xsl:variable>
                                
                                <!-- Assert that only one resource is returned -->
                                <action>
                                    <assert>
                                        <description value="{$description}"/>
                                        <direction value="{$direction}"/>
                                        <expression value="{$resourceExpression}.count() = 1"/>
                                        <warningOnly value="true"/>
                                    </assert>
                                </action>
                                
                                <!-- Return to the fixture and create asserts from that fixture -->
                                <xsl:for-each select="$fixturesResources/*[$position]">
                                    <xsl:variable name="resourceName">
                                        <xsl:call-template name="createResourceName"/>
                                    </xsl:variable>
                                    <xsl:apply-templates select="." mode="asserts">
                                        <xsl:with-param name="resourceName" select="$resourceName" tunnel="yes"/>
                                        <xsl:with-param name="direction" select="$direction" tunnel="yes"/>
                                        <xsl:with-param name="resourceExpression" select="$resourceExpression" tunnel="yes"/>
                                        <xsl:with-param name="level" select="'element'" tunnel="yes"/>
                                        <xsl:with-param name="has-T" as="xs:boolean" tunnel="yes">
                                            <xsl:choose>
                                                <xsl:when test="$TestScriptHasT = true() or $combinedIdExpressionParts/nts:idExpression[contains(text(), '${DATE, T')]">
                                                    <xsl:value-of select="true()"/>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:value-of select="false()"/>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:with-param>
                                    </xsl:apply-templates>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="yes">
                                    <xsl:text>Unable to generate a unique expression from resource with id '</xsl:text>
                                    <xsl:value-of select="@id"/>
                                    <xsl:text>'</xsl:text>
                                </xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </test>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@*|node()" mode="copy"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="nts:generate-asserts-from"/>
    
    <xsl:template match="f:operation" mode="copy">
        <xsl:param name="fixtureId" tunnel="yes"/>
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="$scenario = 'client' and not(f:requestId) and not($fixtureId='')">
                    <xsl:apply-templates select="*[not(self::f:responseId) and not(self::f:sourceId) and not(self::f:targetId) and not(self::f:url)]" mode="#current"/>
                    <requestId value="{$fixtureId}"/>
                    <xsl:apply-templates select="*[self::f:responseId and self::f:sourceId or self::f:targetId or self::f:url]"/>
                </xsl:when>
                <xsl:when test="$scenario = 'server' and not(f:responseId) and not($fixtureId='')">
                    <xsl:apply-templates select="*[not(self::f:sourceId) and not(self::f:targetId) and not(self::f:url)]" mode="#current"/>
                    <responseId value="{$fixtureId}"/>
                    <xsl:apply-templates select="*[self::f:sourceId or self::f:targetId or self::f:url]"/>
                </xsl:when>
                <xsl:otherwise>
                        <xsl:apply-templates select="node()|@*" mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="createResourceName">
        <xsl:variable name="resourceName" select="local-name()"/>
        <xsl:value-of select="$resourceName"/>
        <xsl:text>-</xsl:text>
        <xsl:value-of select="count(preceding::f:*[local-name()=$resourceName])+1"/>
    </xsl:template>
    
    <xsl:template match="node()|@*" mode="copy">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Exclude the following elements from the generated asserts -->
    <xsl:template match="f:text[parent::f:*[not(ancestor::f:*)]]" mode="asserts expression"/>
    <xsl:template match="f:meta/f:lastUpdated | f:meta/f:versionId" mode="asserts expression"/>
    <xsl:template match="f:id[parent::f:*[not(ancestor::f:*)]]" mode="asserts expression"/>
    <xsl:template match="f:coding/f:userSelected" mode="asserts expression"/>
    <!--<xsl:template match="f:coding/f:display | f:display[preceding-sibling::f:system and preceding-sibling::f:code]" mode="asserts expression"/>
    <xsl:template match="f:text[preceding-sibling::f:coding]" mode="asserts expression"/>-->
    
    <xsl:template match="f:*" mode="asserts">
        <xsl:param name="resourceName" tunnel="yes"/>
        <xsl:param name="direction" tunnel="yes"/>
        <xsl:param name="expressionInherited" tunnel="yes"/>
        <xsl:param name="resourceExpression" tunnel="yes"/>
        <xsl:param name="level" tunnel="yes"/>
        <xsl:variable name="expressionLocal">
            <xsl:choose>
                <xsl:when test="not(ancestor::f:*)">
                    <xsl:value-of select="$resourceExpression"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>.</xsl:text>
                    <xsl:value-of select="nf:DTchoice(.)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="description-prefix">
            <xsl:value-of select="$resourceName"/>
            <xsl:text>: </xsl:text>
            <xsl:value-of select="nf:DTchoice(.)"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="self::f:meta/parent::f:*[not(ancestor::f:*)]">
                <xsl:variable name="description">
                    <xsl:value-of select="$description-prefix"/>
                    <xsl:text>.profile equals '</xsl:text>
                    <xsl:value-of select="f:profile/@value"/>
                    <xsl:text>'.</xsl:text>
                </xsl:variable>
                <xsl:variable name="expression">
                    <xsl:value-of select="$expressionInherited"/>
                    <xsl:text>.</xsl:text>
                    <xsl:value-of select="nf:DTchoice(.)"/>
                    <xsl:text>.where($this</xsl:text>
                    <xsl:apply-templates select="f:profile" mode="expression"/>
                    <xsl:text>).exists()</xsl:text>
                </xsl:variable>
                <action>
                    <assert>
                        <description value="{$description}"/>
                        <direction value="{$direction}"/>
                        <expression value="{$expression}"/>
                        <warningOnly value="true"/>
                    </assert>
                </action>
            </xsl:when>
            <xsl:when test="$level = 'resource'">
                <xsl:variable name="description">
                    <xsl:value-of select="$description-prefix"/>
                    <xsl:text> resource tested in one assertion.</xsl:text>
                </xsl:variable>
                <xsl:variable name="expression">
                    <xsl:value-of select="$resourceExpression"/>
                    <xsl:apply-templates select="." mode="expression"/>
                    <xsl:text>.exists()</xsl:text>
                </xsl:variable>
                <action>
                    <assert>
                        <description value="{$description}"/>
                        <direction value="{$direction}"/>
                        <expression value="{$expression}"/>
                        <warningOnly value="true"/>
                    </assert>
                </action>
            </xsl:when>
            <xsl:when test="parent::f:*[not(ancestor::f:*)]">
                <xsl:variable name="description">
                    <xsl:value-of select="$description-prefix"/>
                    <xsl:apply-templates select="." mode="description"/>
                </xsl:variable>
                <xsl:variable name="expression">
                    <xsl:value-of select="$expressionInherited"/>
                    <xsl:apply-templates select="." mode="expression"/>
                    <xsl:text>.exists()</xsl:text>
                </xsl:variable>
                <action>
                    <assert>
                        <description value="{$description}"/>
                        <direction value="{$direction}"/>
                        <expression value="{$expression}"/>
                        <warningOnly value="true"/>
                    </assert>
                </action>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="node()" mode="asserts">
                    <xsl:with-param name="expressionInherited" select="concat($expressionInherited,$expressionLocal)" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="f:*" mode="description">
        <xsl:if test="parent::f:*[not(ancestor::f:*)]">
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:choose>
            <!-- If identifier is present, it should contain system and value -->
            <xsl:when test="self::f:identifier or ends-with(local-name(),'Identifier')">
                <xsl:text>contains Identifier.</xsl:text>
            </xsl:when>
            <!--Reference datatype should contain display (also tested through common asserts) and (reference or identifier). Reference element is not further asserted (this is also tested through common asserts-->
            <xsl:when test="f:display and (f:reference or f:identifier)">
                <xsl:text>contains Reference.</xsl:text>
            </xsl:when>
            <xsl:when test="self::f:extension">
                <xsl:text>is extension.</xsl:text>
            </xsl:when>
            <xsl:when test="f:coding">
                <xsl:text>contains CodeableConcept with correct system and code.</xsl:text>
            </xsl:when>
            <xsl:when test="@value and f:*">
                <xsl:call-template name="get-description-based-on-type"/>
                <xsl:text> and contains nested element.</xsl:text>
            </xsl:when>
            <xsl:when test="@value">
                <xsl:call-template name="get-description-based-on-type"/>
                <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:when test="f:*">
                <xsl:text>contains nested element.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes"></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="f:*" mode="expression">
        <xsl:if test="ancestor::f:*">
        <xsl:text>.</xsl:text>
        <xsl:value-of select="nf:DTchoice(.)"/>
        </xsl:if>
        <xsl:choose>
            <!-- If identifier is present, it should contain system and value -->
            <xsl:when test="self::f:identifier or ends-with(local-name(),'Identifier')">
                <xsl:text>.where($this.system and $this.value)</xsl:text>
            </xsl:when>
            <!--Reference datatype should contain display (also tested through common asserts) and (reference or identifier). Reference element is not further asserted (this is also tested through common asserts-->
            <xsl:when test="f:display and (f:reference or f:identifier)">
                <xsl:text>.where($this.display and ($this.reference or $this.identifier))</xsl:text>
            </xsl:when>
            <xsl:when test="@value and f:*">
                <xsl:text>.where($this</xsl:text>
                <xsl:call-template name="get-expression-based-on-type">
                    <xsl:with-param name="include-where-this" select="false()"/>
                </xsl:call-template>
                <xsl:text> and <!--$this--></xsl:text>
                <xsl:choose>
                    <xsl:when test="count(f:*) = 1">
                        <xsl:text>$this</xsl:text>
                        <xsl:apply-templates select="f:*" mode="#current"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="*">
                            <xsl:variable name="and-this-check">
                                <xsl:if test="preceding-sibling::*">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                                <xsl:text>$this</xsl:text>
                                <xsl:apply-templates select="." mode="#current"/>
                            </xsl:variable>
                            <xsl:if test="not($and-this-check=' and $this')">
                                <xsl:value-of select="$and-this-check"/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:text>)</xsl:text>
            </xsl:when>
            <xsl:when test="@value">
                <xsl:choose>
                    <xsl:when test="parent::f:*[not(ancestor::f:*)]">
                        <xsl:call-template name="get-expression-based-on-type">
                            <xsl:with-param name="include-where-this" select="true()"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="get-expression-based-on-type">
                            <xsl:with-param name="include-where-this" select="false()"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="f:*">
                <xsl:choose>
                    <xsl:when test="count(f:*) = 1">
                        <xsl:apply-templates select="f:*" mode="#current"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>.where(</xsl:text>
                        <xsl:variable name="starts-with-this-and">
                        <xsl:for-each select="*">
                            <xsl:variable name="and-this-check">
                                <xsl:if test="preceding-sibling::*">
                                    <xsl:text> and </xsl:text>
                                </xsl:if>
                                <xsl:text>$this</xsl:text>
                                <xsl:apply-templates select="." mode="#current"/>
                            </xsl:variable>
                            <xsl:if test="not($and-this-check=' and $this')">
                                <xsl:value-of select="$and-this-check"/>
                            </xsl:if>
                        </xsl:for-each>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="starts-with($starts-with-this-and,'$this and ')">
                                <xsl:value-of select="substring-after($starts-with-this-and,'$this and ')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$starts-with-this-and"/>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:text>)</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-type">
        <xsl:param name="has-T" tunnel="yes" select="false()"/>
        <xsl:choose>
            <!-- Profile -->
            <xsl:when test="self::f:profile/parent::f:meta">Profile</xsl:when>
            <!-- Display, text, note-->
            <xsl:when test="self::f:display or self::f:text or self::f:note or self::f:unit or self::f:title or ends-with(local-name(),'String')">String</xsl:when>
            <!-- Code -->
            <xsl:when test="self::f:code">Code</xsl:when>
            <!-- DateTime met T-datum -->
            <xsl:when test="starts-with(@value,'${DATE, T')">
                <xsl:choose>
                    <!-- if T-variable is present within testscript, then use it! -->
                    <xsl:when test="ancestor::f:TestScript/f:variable/f:name/@value='T' or $has-T=true()">TVariable</xsl:when>
                    <!-- else only check for significance -->
                    <xsl:otherwise>
                        <xsl:choose>
                            <xsl:when test="starts-with(@value,'${DATE, T, D') and matches(@value,'(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00))$')">TDateTime</xsl:when>
                            <xsl:when test="starts-with(@value,'${DATE, T, D')">TDate</xsl:when>
                            <!-- Separate when for year-month? -->
                            <xsl:when test="starts-with(@value,'${DATE, T, Y')">TYear</xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="yes">Unhandled type</xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                    <!-- Option to introduce Test Execution-wide variables? KT-229 -->
                </xsl:choose>
            </xsl:when>
            <!-- DateTime zonder T-datum? -->
            <xsl:when test="matches(@value,'^([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)([.][0-9]+)?(Z|([+]|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?$')">DateTime</xsl:when>
            <!-- Number, integer -->
            <xsl:when test="string(number(@value)) != 'NaN'">Number</xsl:when>
            <xsl:when test="@value=('true','false')">Boolean</xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-description-based-on-type">
        <xsl:variable name="type">
            <xsl:call-template name="get-type"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$type='Profile'">
                <xsl:text>equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Code'">
                <xsl:text>with value '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>' exists</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TVariable'">
                <xsl:text>equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDateTime'">
                <xsl:text>equals date, time and timezone</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDate'">
                <xsl:text>equals date</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TYear'">
                <xsl:text>equals year</xsl:text>
            </xsl:when>
            <xsl:when test="$type='DateTime'">
                <xsl:text>equals DateTime '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Number'">
                <xsl:text>equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='String'">
                <xsl:text>exists</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Boolean'">
                <xsl:text>equals </xsl:text>
                <xsl:value-of select="@value"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-expression-based-on-type">
        <xsl:param name="include-where-this" select="true()"/>
        <xsl:param name="has-T" tunnel="yes" select="false()"/>
        <xsl:variable name="type">
            <xsl:call-template name="get-type"/>
        </xsl:variable>
        <xsl:if test="$include-where-this">
            <xsl:text>.where($this</xsl:text>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="$type='String'">
                <!--<xsl:text>.exists()</xsl:text>-->
                <!--<xsl:text>.where($this.toString().matches('(?i)</xsl:text>
                <xsl:value-of select="replace(@value,
                    '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','[$1]')"/>
                <xsl:text>')).exists()</xsl:text>-->
            </xsl:when>
            <xsl:when test="$type='Profile'">
                <xsl:text> = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Code'">
                <xsl:text> = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TVariable'">
                <xsl:text> = @</xsl:text>
                <xsl:value-of select="@value"/>
            </xsl:when>
            <xsl:when test="$type='TDateTime'">
                <!-- Regex modified from FHIR dateTime datatype - made time non-optional -->
                <!-- Original: ([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\.[0-9]+)?(Z|(+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)? -->
                <xsl:text>.toString().matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)([.][0-9]+)?(Z|([+]|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))))')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDate'">
                <!-- Regex copied from FHIR date datatype -->
                <!-- ([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)? -->
                <xsl:text>.toString().matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TYear'">
                <xsl:text>.toString().matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='DateTime'">
                <xsl:text> = @</xsl:text>
                <xsl:value-of select="@value"/>
            </xsl:when>
            <xsl:when test="$type='Number'">
                <xsl:text> = </xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text></xsl:text>
            </xsl:when>
            <xsl:when test="$type='Boolean'">
                <xsl:text> = </xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text></xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="$include-where-this">
            <xsl:text>)</xsl:text>
        </xsl:if>
    </xsl:template>
    
    <!-- extensions! -->
    <xsl:function name="nf:DTchoice">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="localName" select="$element/local-name()"/>
        <xsl:choose>
            <xsl:when test="$localName = 'extension' and $element/@url">
                <xsl:value-of select="$localName"/>
                <xsl:text>.where(url='</xsl:text>
                <xsl:value-of select="$element/@url"/>
                <xsl:text>')</xsl:text>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Address')">
                <xsl:value-of select="substring-before($localName,'Address')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Annotation')">
                <xsl:value-of select="substring-before($localName,'Annotation')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Attachment')">
                <xsl:value-of select="substring-before($localName,'Attachment')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Boolean')">
                <xsl:value-of select="substring-before($localName,'Boolean')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'CodeableConcept')">
                <xsl:value-of select="substring-before($localName,'CodeableConcept')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Coding')">
                <xsl:value-of select="substring-before($localName,'Coding')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Code') and not($localName='postalCode')">
                <xsl:value-of select="substring-before($localName,'Code')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'ContactPoint')">
                <xsl:value-of select="substring-before($localName,'ContactPoint')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Count')">
                <xsl:value-of select="substring-before($localName,'Count')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Date') and not($localName = ('assertedDate','birthDate'))">
                <xsl:value-of select="substring-before($localName,'Date')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'DateTime')">
                <xsl:value-of select="substring-before($localName,'DateTime')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Decimal')">
                <xsl:value-of select="substring-before($localName,'Decimal')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Dosage')">
                <xsl:value-of select="substring-before($localName,'Dosage')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'HumanName')">
                <xsl:value-of select="substring-before($localName,'HumanName')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Identifier')">
                <xsl:value-of select="substring-before($localName,'Identifier')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Integer')">
                <xsl:value-of select="substring-before($localName,'Integer')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Period')">
                <xsl:value-of select="substring-before($localName,'Period')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Quantity')">
                <xsl:value-of select="substring-before($localName,'Quantity')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Age')">
                <xsl:value-of select="substring-before($localName,'Age')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Distance')">
                <xsl:value-of select="substring-before($localName,'Distance')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Duration')">
                <xsl:value-of select="substring-before($localName,'Duration')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Money')">
                <xsl:value-of select="substring-before($localName,'Money')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'SimpleQuantity')">
                <xsl:value-of select="substring-before($localName,'SimpleQuantity')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Ratio')">
                <xsl:value-of select="substring-before($localName,'Ratio')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Reference')">
                <xsl:value-of select="substring-before($localName,'Reference')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'SampledData')">
                <xsl:value-of select="substring-before($localName,'SampledData')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'String')">
                <xsl:value-of select="substring-before($localName,'String')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Time')">
                <xsl:value-of select="substring-before($localName,'Time')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Timing')">
                <xsl:value-of select="substring-before($localName,'Timing')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Uri')">
                <xsl:value-of select="substring-before($localName,'Uri')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$localName"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>