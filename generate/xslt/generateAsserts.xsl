<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:f="http://hl7.org/fhir"
    xmlns:nf="http://www.nictiz.nl/functions"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <!-- 
        
        TO-DO/WISH LIST:
        
        - Exclude specific parts of fixture when generating?
        
        - Better readable discriptions.
        
        - Refactor expectedResponseFormat to be added after assertions are generated
        - Refactor 'filter' mode in generateTestScript to be matched to separate 'filterTestScript.xsl'.
        
        - Is it possible to generate assertions from a singe resource instead of a bundle?
        - '_fixtures' folder not necessary, can also be '_resources' folder. Look at generateTestScript to see how filenames are resolved.
        - Edit (or automate?) the relevant resources to look at (scenarioResources variable). Maybe based on selflink?
        - Edit the descriptions to better reflect what is tested based on datatype.
        - Investigate the possibility to, upon failure, let de description give a hint to what needs to be searched for in the response to get to the relevant part.
        - Look at expression parts: is it possible to have a resource that has no unique content per se, but still is unique in the combination of everything.
        
        - Handle client POST/PUTs that a server receives with minimumId instead of generating asserts. Depends on KT-198.
        
        DEPENDS ON KT-226:
        - Edit readme: "The `test` element where this attribute is added to will be duplicated (because responses cannot be transferred between tests)"
        
    -->
    
    <!--<xsl:param name="fixtureFolder" as="xs:string" required="yes"/>-->
    <xsl:param name="fixtureFolder" as="xs:string" select="'file:/C:/Users/144189-ADM/Documents/Git/Nictiz-STU3-testscripts/Generate/src/Medication-9-0-7/_fixtures'"/>
    <xsl:param name="scenario" as="xs:string"/>
    
    <xsl:param name="scenarioType" select="'MA'"/>
    <xsl:variable name="scenarioResources" select="('MedicationRequest','Medication')"/>
    
    <xsl:output indent="yes"/>
    
    <xsl:template match="node()|@*" mode="#all" priority="-1">
        <xsl:apply-templates select="node()|@*" mode="#current"/>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:if test="not($scenario=('server','client'))">
            <xsl:message terminate="yes">Scenario value '<xsl:value-of select="$scenario"/>' not recognized. Should be one of 'server,client'.</xsl:message>
        </xsl:if>
        <xsl:copy>
            <xsl:apply-templates select="node()" mode="copy"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="f:TestScript/f:test[@nts:generate-asserts-from]" mode="copy">
        <xsl:choose>
            <!-- Make sure @nts:generate-asserts-from is only added to tests where it is relevant, otherwise ignore. -->
            <!-- Edge case: when a server receives a POST or PUT, asserts are generated, but as it is supposed to send back the complete resource (with only resource.id added), perhaps using minimumId is more elegant. -->
            <xsl:when test="$scenario = 'server' or 
                f:action/f:operation/f:type[f:system/@value = 'http://hl7.org/fhir/testscript-operation-codes']/
                f:code/@value=('batch','transaction','create','update','updateCreate')">
                <xsl:variable name="test-count" select="count(preceding-sibling::f:test)+1"/>
                <xsl:variable name="asserts-fixture" select="document(string-join(($fixtureFolder, @nts:generate-asserts-from), '/'),.)"/>
                <xsl:variable name="fixture-id">
                    <xsl:choose>
                        <xsl:when test="$scenario = 'client'">
                            <xsl:choose>
                                <xsl:when test="f:action/f:operation/f:requestId/@value">
                                    <xsl:value-of select="f:action/f:operation/f:requestId/@value"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('contentasserts-request-',$test-count)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$scenario = 'server'">
                            <xsl:choose>
                                <xsl:when test="f:action/f:operation/f:responseId/@value">
                                    <xsl:value-of select="f:action/f:operation/f:responseId/@value"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('contentasserts-response-',$test-count)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                    </xsl:choose>
                </xsl:variable>
                <xsl:if test="not($asserts-fixture)">
                    <xsl:message terminate="yes">Fixture <xsl:value-of select="$asserts-fixture"/> not found.</xsl:message>
                </xsl:if>
                <xsl:copy>
                    <xsl:apply-templates select="node()|@*" mode="copy">
                        <xsl:with-param name="fixture-id" tunnel="yes" select="$fixture-id"/>
                    </xsl:apply-templates>
                    <xsl:variable name="idExpressionParts">
                        <nts:idExpressions>
                            <xsl:for-each select="$asserts-fixture/f:Bundle/f:entry/f:resource/f:*[local-name()=$scenarioResources]">
                                <nts:idExpression resource="{local-name()}">
                                    <xsl:attribute name="name">
                                        <xsl:call-template name="create-resourceID"/>
                                    </xsl:attribute>
                                    <xsl:call-template name="generateExpressionParts">
                                        <xsl:with-param name="in" select="."/>
                                    </xsl:call-template>
                                </nts:idExpression>
                            </xsl:for-each>
                        </nts:idExpressions>
                    </xsl:variable>
                    <xsl:variable name="filteredIdExpressionParts">
                        <xsl:apply-templates select="$idExpressionParts" mode="filterExpressions"/>
                    </xsl:variable>
                    <xsl:variable name="combinedIdExpressionParts">
                        <xsl:apply-templates select="$filteredIdExpressionParts" mode="combineExpressions"/>
                    </xsl:variable>
                    <nts:generated-asserts>
                        <xsl:choose>
                            <xsl:when test="count($combinedIdExpressionParts/nts:idExpression) = count(distinct-values($combinedIdExpressionParts/nts:idExpression))">
                                <xsl:for-each select="$combinedIdExpressionParts/nts:idExpression">
                                    <xsl:variable name="resourceID">
                                        <xsl:call-template name="create-resourceID"/>
                                    </xsl:variable>
                                    <variable>
                                        <name value="{@name}"/>
                                        <expression value="Bundle.entry.select(resource as {@resource}).where({./text()}).id"/>
                                        <sourceId value="{$fixture-id}"/>
                                    </variable>
                                    <action>
                                        <assert>
                                            <description value="CONTENT ASSERTION ID MATCH - Check if variable '{@name}' can be matched to a resource in the response."/>
                                            <expression value="Bundle.entry.select(resource as MedicationRequest).where(id = '${{{@name}}}').count() = 1"/>
                                            <!-- Should be warning or not? <warningOnly value="true"/>-->
                                        </assert>
                                    </action>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="yes">Could not determine unique expression to catch ID in a variable.</xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:apply-templates select="$asserts-fixture" mode="asserts"/>
                    </nts:generated-asserts>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@*|node()" mode="copy"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="f:operation" mode="copy">
        <xsl:param name="fixture-id" tunnel="yes"/>
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="$scenario = 'client' and not(f:requestId) and not($fixture-id='')">
                    <xsl:apply-templates select="*[not(self::f:responseId) and not(self::f:sourceId) and not(self::f:targetId) and not(self::f:url)]" mode="#current"/>
                    <requestId value="{$fixture-id}"/>
                    <xsl:apply-templates select="*[self::f:responseId and self::f:sourceId or self::f:targetId or self::f:url]"/>
                </xsl:when>
                <xsl:when test="$scenario = 'server' and not(f:responseId) and not($fixture-id='')">
                    <xsl:apply-templates select="*[not(self::f:sourceId) and not(self::f:targetId) and not(self::f:url)]" mode="#current"/>
                    <responseId value="{$fixture-id}"/>
                    <xsl:apply-templates select="*[self::f:sourceId or self::f:targetId or self::f:url]"/>
                </xsl:when>
                <xsl:otherwise>
                        <xsl:apply-templates select="node()|@*" mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="generateExpressionParts">
        <xsl:param name="in" select="."/>
        <xsl:for-each select="$in//@value[string(number(.)) != 'NaN' or parent::f:code]"><!-- only apply values that are numbers (integers) and codes. prevent ambiguity -->
            <nts:expressionPart>
                <xsl:for-each select="ancestor::*[ancestor::f:*[parent::f:resource]]">
                    <xsl:value-of select="nf:DTchoice(.)"/>
                    <xsl:if test="not(position()=last())">
                        <xsl:text>.</xsl:text>
                    </xsl:if>
                </xsl:for-each>
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
    </xsl:template>
    
    <xsl:template match="nts:idExpression" mode="filterExpressions">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="nts:expressionPart">
                <xsl:variable name="contents" select="./text()"/>
                <xsl:variable name="resource" select="parent::nts:idExpression/@resource"/>
                <xsl:choose>
                    <xsl:when test="count(ancestor::nts:idExpressions/nts:idExpression[@resource = $resource]) gt 1 and count(ancestor::nts:idExpressions/nts:idExpression[@resource = $resource]) = count(ancestor::nts:idExpressions/nts:idExpression[@resource = $resource]/nts:expressionPart[text()=$contents])"/>
                    <xsl:when test="count(ancestor::nts:idExpressions/nts:idExpression[@resource = $resource]) = 1">
                        <xsl:choose>
                            <xsl:when test="position() = 1">
                                <xsl:copy-of select="."/>
                            </xsl:when>
                            <xsl:otherwise/>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="."/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="nts:idExpression" mode="combineExpressions">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="nts:expressionPart">
                <xsl:value-of select="."/>
                <xsl:if test="not(position()=last())"> and </xsl:if>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="create-resourceID">
        <xsl:variable name="resourceName" select="ancestor-or-self::f:entry/f:resource/f:*/local-name()"/>
        <xsl:value-of select="$resourceName"/>
        <xsl:text>-</xsl:text>
        <xsl:value-of select="count(ancestor-or-self::f:entry/preceding-sibling::f:entry/f:resource/f:*[local-name()=$resourceName])+1"/>
    </xsl:template>
    
    <!--<xsl:template match="@nts:generate-asserts-from" mode="copy"/>-->
    
    <xsl:template match="node()|@*" mode="copy">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Exclusions -->
    <xsl:template match="f:entry/f:fullUrl" mode="asserts"/>
    <xsl:template match="f:entry/f:resource/f:*/f:text" mode="asserts"/>
    <xsl:template match="f:entry/f:search" mode="asserts"/>
    
    <xsl:template match="@value[ancestor::f:resource/f:*[local-name()=$scenarioResources]]" mode="asserts">
        <xsl:choose>
            <!-- Do nothing when matching the system part of a Coding.system/code pair. -->
            <xsl:when test="parent::f:system/parent::*[self::f:coding or ends-with(local-name(),'Coding')]"/>
            <xsl:otherwise>
                <xsl:variable name="resourceExpression">
                    <xsl:for-each select="ancestor::*[descendant-or-self::f:*[local-name()=$scenarioResources]]">
                        <xsl:choose>
                            <xsl:when test="self::f:resource"/>
                            <xsl:when test="self::f:*[local-name()=$scenarioResources]">
                                <xsl:text>.</xsl:text>
                                <xsl:text>select(resource as </xsl:text>
                                <xsl:value-of select="local-name()"/>
                                <xsl:text>).where(id = '${</xsl:text>
                                <xsl:call-template name="create-resourceID"/>
                                <xsl:text>}')</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:if test="not(self::f:Bundle)">
                                    <xsl:text>.</xsl:text>
                                </xsl:if>
                                <xsl:value-of select="nf:DTchoice(.)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="withinResourceExpression">
                    <xsl:for-each select="ancestor::*[ancestor::f:*[local-name()=$scenarioResources]]">
                        <xsl:choose>
                            <!-- Do nothing when matching the code parent of a Coding.system/code pair. -->
                            <xsl:when test="self::f:code[parent::*[self::f:coding or ends-with(local-name(),'Coding')]/f:system/@value]"/>
                            <xsl:otherwise>
                                <xsl:text>.</xsl:text>
                                <xsl:value-of select="nf:DTchoice(.)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="expression">
                    <xsl:value-of select="$resourceExpression"/>
                    <xsl:value-of select="$withinResourceExpression"/>
                    <xsl:choose>
                        <!-- Profile -->
                        <xsl:when test="parent::f:profile/parent::f:meta">
                            <xsl:text>.startsWith('</xsl:text>
                            <xsl:value-of select="."/>
                            <xsl:text>')</xsl:text>
                        </xsl:when>
                        <!-- Code -->
                        <!-- combine coding.system and .code in one assert -->
                        <xsl:when test="parent::f:code/parent::*[self::f:coding or ends-with(local-name(),'Coding')]/f:system/@value">
                            <xsl:text>.where($this.system = '</xsl:text>
                            <xsl:value-of select="parent::f:code/parent::*[self::f:coding or ends-with(local-name(),'Coding')]/f:system/@value"/>
                            <xsl:text>' and $this.code = '</xsl:text>
                            <xsl:value-of select="."/>
                            <xsl:text>').exists()</xsl:text>
                        </xsl:when>
                        <!-- fallback when system is not present -->
                        <xsl:when test="parent::f:code">
                            <xsl:text>.where($this = '</xsl:text>
                            <xsl:value-of select="."/>
                            <xsl:text>').exists()</xsl:text>
                        </xsl:when>
                        <!-- DateTime met T-datum -->
                        <xsl:when test="starts-with(.,'${DATE, T')">
                            <!-- exists? -->
                            <xsl:text>.exists()</xsl:text>
                            <!-- calculate from current date? -->
                            <!-- regex to check if accuracy of addendum is achieved? -->
                            <!-- possible to put CURRENTDATE in assertion? -->
                        </xsl:when>
                        <!-- DateTime zonder T-datum? -->
                        <!-- parent is Identifier -->
                        <xsl:when test="parent::f:*/parent::f:*[local-name()='identifier' or ends-with(local-name(),'Identifier')]">
                            <xsl:text>.exists()</xsl:text>
                        </xsl:when>
                        <!-- References -->
                        <xsl:when test="parent::f:reference">
                            <xsl:text>.exists()</xsl:text>
                        </xsl:when>
                        <!-- Number, integer -->
                        <xsl:when test="string(number(.)) != 'NaN'">
                            <!--<xsl:when test=". = number(.)">-->
                            <xsl:text> = </xsl:text>
                            <xsl:value-of select="."/>
                        </xsl:when>
                        <!-- Display, text, note-->
                        <xsl:when test="parent::f:display or parent::f:text or parent::f:note or parent::f:unit">
                            <xsl:text>.where($this.matches('(?i)</xsl:text>
                            <xsl:value-of select="replace(.,
                                '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','[$1]')"/>
                            <xsl:text>')).exists()</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>.where($this = '</xsl:text>
                            <xsl:value-of select="."/>
                            <xsl:text>').exists()</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="description">
                    <!-- Because duplication is removed because of KT-228, start every description with 'CONTENT ASSERTION' -->
                    <xsl:text>CONTENT ASSERTION - </xsl:text>
                    <xsl:call-template name="create-resourceID"/>
                    <xsl:text>: Check if </xsl:text>
                    <xsl:value-of select="substring-after($withinResourceExpression,'.')"/>
                    <xsl:text> conforms to addendum.</xsl:text>
                </xsl:variable>
                <action>
                    <assert>
                        <description value="{$description}"/>
                        <expression value="{$expression}"/>
                        <warningOnly value="true"/>
                    </assert>
                </action>
            </xsl:otherwise>
        </xsl:choose>
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
            <xsl:when test="ends-with($localName,'Code')">
                <xsl:value-of select="substring-before($localName,'Code')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'ContactPoint')">
                <xsl:value-of select="substring-before($localName,'ContactPoint')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Count')">
                <xsl:value-of select="substring-before($localName,'Count')"/>
            </xsl:when>
            <xsl:when test="ends-with($localName,'Date')">
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