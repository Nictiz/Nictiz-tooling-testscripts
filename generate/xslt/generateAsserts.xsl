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
        - Refactor 'filter' mode in generateTestScript to be matched to separate 'filterTestScript.xsl'.
        
        - '_fixtures' folder not necessary, can also be '_resources' folder. Look at generateTestScript to see how filenames are resolved.
        - Look at expression parts: is it possible to have a resource that has no unique content per se, but still is unique in the combination of everything.
        
        - Handle client POST/PUTs that a server receives with minimumId instead of generating asserts. Depends on KT-198.
        
        DEPENDS ON KT-226:
        - Edit readme: "The `test` element where this attribute is added to will be duplicated (because responses cannot be transferred between tests)"
        
    -->
    
    <xsl:param name="referenceFolder" as="xs:string" required="yes"/>
    <xsl:param name="referenceGenerateFolder" as="xs:string" required="yes"/>
    <xsl:param name="scenario" as="xs:string" required="yes"/>
    
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
        <xsl:variable name="operation-code" select="f:action/f:operation/f:type[f:system/@value = 'http://hl7.org/fhir/testscript-operation-codes']/f:code/@value"/>
        <xsl:choose>
            <!-- Make sure @nts:generate-asserts-from is only added to tests where it is relevant, otherwise ignore. -->
            <!-- Edge case: when a server receives a POST or PUT, asserts are generated, but as it is supposed to send back the complete resource (with only resource.id added), perhaps using minimumId is more elegant. -->
            <xsl:when test="$scenario = 'server' or 
                $operation-code = ('batch','transaction','create','update','updateCreate')">
                <xsl:variable name="generate-from-all" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="not($operation-code = ('read','vread','search'))">
                            <xsl:value-of select="true()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="false()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="generate-from-resources" as="element()*">
                    <!-- resource is specified for 'read', 'vread' and 'search' operations. -->
                    <xsl:variable name="resource" select="f:action/f:operation/f:resource/@value"/>
                    <xsl:variable name="params" select="f:action/f:operation/f:params/@value"/>
                    <xsl:if test="$resource">
                        <resource name="{$resource}"/>
                    </xsl:if>
                    <xsl:if test="contains($params,'_include=')">
                        <xsl:variable name="after-include" select="substring-after($params,'_include=')"/>
                        <xsl:variable name="before-amp">
                            <xsl:choose>
                                <xsl:when test="contains($after-include,'&amp;')">
                                    <xsl:value-of select="substring-before($after-include,'&amp;')"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$after-include"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:variable>
                        <xsl:if test="not(substring-after($before-amp,concat($resource,':'))='')">
                            <xsl:variable name="search-param" select="substring-after($before-amp,concat($resource,':'))"/>
                            <xsl:choose>
                                <xsl:when test="$search-param='medication'">
                                    <resource name="Medication"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:message terminate="yes">Unknown _include search param</xsl:message>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:if>
                    </xsl:if>
                </xsl:variable>
                
                <xsl:variable name="test-count" select="count(preceding-sibling::f:test)+1"/>
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
                <xsl:variable name="direction">
                    <xsl:choose>
                        <xsl:when test="$generate-from-all">
                            <xsl:value-of select="'request'"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="'response'"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="asserts-fixtures" select="tokenize(@nts:generate-asserts-from,'[,\s]+')"/>
                <xsl:variable name="asserts-fixtures-normalized">
                    <xsl:for-each select="$asserts-fixtures">
                        <xsl:variable name="raw" select="."/>
                        <xsl:variable name="check-extension">
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
                            <xsl:when test="doc-available(string-join(($referenceFolder,$check-extension),'/'))">
                                <xsl:value-of select="string-join(($referenceFolder, $check-extension), '/')"/>
                            </xsl:when>
                            <xsl:when test="doc-available(string-join(($referenceGenerateFolder,$check-extension),'/'))">
                                <xsl:value-of select="string-join(($referenceGenerateFolder, $check-extension), '/')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="yes">Fixture <xsl:value-of select="$check-extension"/> not found.</xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                <!-- Extract all resources, from Bundle if necessary -->
                <xsl:variable name="asserts-fixtures-resources">
                    <xsl:for-each select="$asserts-fixtures-normalized">
                        <xsl:variable name="asserts-fixture" select="document(.)"/>
                        <xsl:choose>
                            <xsl:when test="$asserts-fixture/f:Bundle">
                                <xsl:for-each select="$asserts-fixture/f:Bundle/f:entry/f:resource/f:*[$generate-from-all or local-name()=$generate-from-resources/@name]">
                                    <xsl:copy-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:when test="$asserts-fixture/f:*[$generate-from-all or local-name()=$generate-from-resources/@name]">
                                <xsl:for-each select="$asserts-fixture/f:*[$generate-from-all or local-name()=$generate-from-resources/@name]">
                                    <xsl:copy-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                
                <xsl:copy>
                    <xsl:apply-templates select="node()|@*" mode="copy">
                        <xsl:with-param name="fixture-id" tunnel="yes" select="$fixture-id"/>
                    </xsl:apply-templates>
                    <nts:generated-asserts>
                        <xsl:variable name="idExpressionParts">
                            <nts:idExpressions>
                                <xsl:for-each select="$asserts-fixtures-resources/*">
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
                        <xsl:choose>
                            <xsl:when test="count($combinedIdExpressionParts/nts:idExpression) = count(distinct-values($combinedIdExpressionParts/nts:idExpression))">
                                <xsl:for-each select="$combinedIdExpressionParts/nts:idExpression">
                                    <xsl:variable name="resource" select="@resource"/>
                                    <xsl:variable name="expression">
                                        <xsl:text>Bundle.entry.select(resource as </xsl:text>
                                        <xsl:value-of select="$resource"/>
                                        <xsl:text>)</xsl:text>
                                        <!-- Only use the expression if there are multiple of the same resources in the generated asserts. This is more loose approach to prevent the whole resource contents being tested in this expression -->
                                        <xsl:if test="count($combinedIdExpressionParts/nts:idExpression[@resource = $resource]) gt 1">
                                            <xsl:text>.where(</xsl:text>
                                            <xsl:value-of select="text()"/>
                                            <xsl:text>)</xsl:text>
                                        </xsl:if>
                                        <xsl:text>.id</xsl:text>
                                    </xsl:variable>
                                    <variable>
                                        <name value="{@name}"/>
                                        <expression value="{$expression}"/>
                                        <sourceId value="{$fixture-id}"/>
                                    </variable>
                                    <action>
                                        <assert>
                                            <description value="Check if variable '{@name}' can be matched to exactly one resource."/>
                                            <direction value="{$direction}"/>
                                            <expression value="Bundle.entry.select(resource as {@resource}).where(id = '${{{@name}}}').count() = 1"/>
                                            <!-- Should be warning or not? <warningOnly value="true"/>-->
                                        </assert>
                                    </action>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="yes">Could not determine unique expression to catch ID in a variable.</xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:for-each select="$asserts-fixtures-resources/*">
                            <xsl:variable name="resourceID">
                                <xsl:call-template name="create-resourceID"/>
                            </xsl:variable>
                            <xsl:apply-templates select="." mode="asserts">
                                <xsl:with-param name="resourceID" select="$resourceID" tunnel="yes"/>
                                <xsl:with-param name="direction" select="$direction" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:for-each>
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
        <xsl:param name="resourcename" select="$in/local-name()"></xsl:param>
        <!--<xsl:param name="generate-from-all" as="xs:boolean"/>
        <xsl:param name="generate-from-resources" as="element()*"/>-->
        <xsl:for-each select="$in//@value[string(number(.)) != 'NaN' or parent::f:code][not(parent::f:versionId) and not(ancestor::f:identifier)]"><!-- only apply values that are numbers (integers) and codes. prevent ambiguity -->
            <nts:expressionPart>
                <xsl:for-each select="ancestor::*[ancestor::*[local-name()=$resourcename]]">
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
                        <xsl:copy-of select="."/>
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
    
    <!-- Exclusions -->
    <xsl:template match="f:text[parent::f:*[not(ancestor::f:*)]]" mode="asserts expression"/>
    <xsl:template match="f:meta/f:lastUpdated | f:meta/f:versionId" mode="asserts expression"/>
    <xsl:template match="f:id[parent::f:*[not(ancestor::f:*)]]" mode="asserts expression"/>
    <xsl:template match="f:coding/f:userSelected" mode="asserts expression"/>
    <xsl:template match="f:coding/f:display | f:display[preceding-sibling::f:system and preceding-sibling::f:code]" mode="asserts expression"/>
    <xsl:template match="f:text[preceding-sibling::f:coding]" mode="asserts expression"/>
    
    
    <xsl:template match="f:*" mode="asserts">
        <xsl:param name="resourceID" tunnel="yes"/>
        <xsl:param name="direction" tunnel="yes"/>
        <xsl:param name="expression-inherited" tunnel="yes"/>
        <xsl:variable name="expression-local">
            <xsl:choose>
                <xsl:when test="not(ancestor::f:*)">
                    <xsl:text>Bundle.entry</xsl:text>
                    <xsl:text>.select(resource as </xsl:text>
                    <xsl:value-of select="local-name()"/>
                    <xsl:text>).where(id = '${</xsl:text>
                    <xsl:value-of select="$resourceID"/>
                    <xsl:text>}')</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>.</xsl:text>
                    <xsl:value-of select="nf:DTchoice(.)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="description-prefix">
            <xsl:value-of select="$resourceID"/>
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
                    <xsl:value-of select="$expression-inherited"/>
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
            <xsl:when test="parent::f:*[not(ancestor::f:*)]">
                <xsl:variable name="description">
                    <xsl:value-of select="$description-prefix"/>
                    <xsl:apply-templates select="." mode="description"/>
                </xsl:variable>
                <xsl:variable name="expression">
                    <xsl:value-of select="$expression-inherited"/>
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
                    <xsl:with-param name="expression-inherited" select="concat($expression-inherited,$expression-local)" tunnel="yes"/>
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
            <xsl:when test="@value">
                <xsl:call-template name="get-description-based-on-type"/>
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
        <xsl:text>.</xsl:text>
        <xsl:value-of select="nf:DTchoice(.)"/>
        <xsl:choose>
            <!-- If identifier is present, it should contain system and value -->
            <xsl:when test="self::f:identifier or ends-with(local-name(),'Identifier')">
                <xsl:text>.where($this.system and $this.value)</xsl:text>
            </xsl:when>
            <!--Reference datatype should contain display (also tested through common asserts) and (reference or identifier). Reference element is not further asserted (this is also tested through common asserts-->
            <xsl:when test="f:display and (f:reference or f:identifier)">
                <xsl:text>.where($this.display and ($this.reference or $this.identifier))</xsl:text>
            </xsl:when>
            <xsl:when test="@value">
                <xsl:call-template name="get-expression-based-on-type"/>
            </xsl:when>
            <xsl:when test="*">
                <xsl:text>.where(</xsl:text>
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
                <xsl:text>)</xsl:text>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-type">
        <xsl:choose>
            <!-- Profile -->
            <xsl:when test="self::f:profile/parent::f:meta">Profile</xsl:when>
            <!-- Code -->
            <xsl:when test="self::f:code">Code</xsl:when>
            <!-- DateTime met T-datum -->
            <xsl:when test="starts-with(@value,'${DATE, T')">
                <xsl:choose>
                    <!-- if T-variable is present within testscript, then use it! -->
                    <xsl:when test="ancestor::f:TestScript/f:variable/f:name/@value='T'">TVariable</xsl:when>
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
            <!-- Number, integer -->
            <xsl:when test="string(number(@value)) != 'NaN'">Number</xsl:when>
            <!-- Display, text, note-->
            <xsl:when test="self::f:display or self::f:text or self::f:note or self::f:unit">Display</xsl:when>
            <xsl:when test="@value=('true','false')">Boolean</xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-description-based-on-type">
        <xsl:variable name="type">
            <xsl:call-template name="get-type"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$type='Profile'">
                <xsl:text> equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Code'">
                <xsl:text> with value '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>' exists.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TVariable'">
                <xsl:text> equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDateTime'">
                <xsl:text> contains date, time and timezone.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDate'">
                <xsl:text> contains date.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TYear'">
                <xsl:text> contains year.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Number'">
                <xsl:text> equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Display'">
                <xsl:text> exists.</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Boolean'">
                <xsl:text> equals </xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> equals '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'.</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="get-expression-based-on-type">
        <xsl:variable name="type">
            <xsl:call-template name="get-type"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$type='Profile'">
                <xsl:text> = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Code'">
                <xsl:text>.where($this = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>').exists()</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TVariable'">
                <xsl:text> = </xsl:text>
                <xsl:value-of select="@value"/>
            </xsl:when>
            <xsl:when test="$type='TDateTime'">
                <!-- Regex modified from FHIR dateTime datatype - made time non-optional -->
                <!-- Original: ([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)? -->
                <xsl:text>.matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)([.][0-9]+)?(Z|([+]|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))))')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TDate'">
                <!-- Regex copied from FHIR date datatype -->
                <!-- ([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)? -->
                <xsl:text>.matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='TYear'">
                <xsl:text>.matches('([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)')</xsl:text>
            </xsl:when>
            <xsl:when test="$type='Number'">
                <xsl:text> = </xsl:text>
                <xsl:value-of select="@value"/>
            </xsl:when>
            <xsl:when test="$type='Display'">
                <xsl:text>.exists()</xsl:text>
                <!--<xsl:text>.where($this.matches('(?i)</xsl:text>
                <xsl:value-of select="replace(@value,
                    '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','[$1]')"/>
                <xsl:text>')).exists()</xsl:text>-->
            </xsl:when>
            <xsl:when test="$type='Boolean'">
                <xsl:text>.where($this = </xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>).exists()</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>.where($this = '</xsl:text>
                <xsl:value-of select="@value"/>
                <xsl:text>').exists()</xsl:text>
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
            <xsl:when test="ends-with($localName,'Code') and not($localName='postalCode')">
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