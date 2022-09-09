<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:f="http://hl7.org/fhir"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:nf="http://www.nictiz.nl/functions"
    xmlns:TODO="TODO"
    xmlns="http://hl7.org/fhir"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    
    <xsl:param name="debug" select="true()"/>
    
    <!--<xsl:param name="fhirPackage" select="'nictiz.fhir.nl.r4.patientcorrections'"/>-->
    <xsl:param name="fhirPackage" select="'nictiz.fhir.nl.r4.medicationprocess9'"/>
    <xsl:param name="fhirPackageVersion" select="'1.0.0'"/>
    
    <xsl:template match="/">
        <xsl:variable name="fileName" select="substring-before(tokenize(base-uri(),'/')[last()], '.xml')"/>
        <xsl:variable name="resourceType" select="local-name(*)"/>
        
        <StructureDefinition xmlns="http://hl7.org/fhir">
            <id value="{$fileName}"/>
            <url value="http://nictiz.nl/fhir/StructureDefinition/Test/{$fileName}"/>
            <name value="{replace($fileName, '-', '')}"/>
            <title value="{replace($fileName, '-', ' ')}"/>
            <status value="draft"/>
            <experimental value="true"/>
            <description value="Constrained profile for qualification purposes. Not suited for implementation."/>
            <fhirVersion value="4.0.1"/>
            <kind value="resource"/>
            <abstract value="false"/>
            <!-- We always create a Bundle profile. If the transformation is applied to a single resource, we assume searchset Bundle -->
            <type value="Bundle"/>
            <baseDefinition value="http://hl7.org/fhir/StructureDefinition/Bundle"/>
            <derivation value="constraint"/>
            <differential>
                <xsl:choose>
                    <!-- Currently works on a Bundle fixture and only processes the first entry. If there are multiple entries to be checked, can we combine them in 1 profile? -->
                    <xsl:when test="f:Bundle">
                        <xsl:apply-templates select="*/*">
                            <xsl:with-param name="elementId" select="$resourceType"/>
                            <xsl:with-param name="path" select="$resourceType"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <element id="Bundle.type">
                            <path value="Bundle.type"/>
                            <fixedCode value="searchset"/>
                        </element>
                        <xsl:variable name="elementId" select="concat('Bundle.entry:', lower-case($resourceType))"/>
                        <xsl:variable name="path" select="'Bundle.entry'"/>
                        <xsl:variable name="profile" select="f:*/f:meta/f:profile[1]/@value"/>
                        <xsl:variable name="structureDefinition">
                            <xsl:call-template name="getStructureDefinition">
                                <xsl:with-param name="profile" select="$profile"/>
                            </xsl:call-template>
                        </xsl:variable>
                        <element id="Bundle.entry">
                            <path value="{$path}"/>
                            <slicing>
                                <discriminator>
                                    <type value="profile"/>
                                    <path value="resource"/>
                                </discriminator>
                                <rules value="open"/>
                            </slicing>
                        </element>
                        <element id="{$elementId}">
                            <path value="{$path}"/>
                            <sliceName value="{lower-case($resourceType)}"/>
                            <min value="1"/>
                            <max value="1"/>
                        </element>
                        <element id="{$elementId}.resource">
                            <path value="{$path}.resource"/>
                            <min value="1"/>
                            <type>
                                <code value="Resource"/>
                                <profile value="{$profile}"/>
                            </type>
                            <!-- If we want to check DateTimes relative to each other, I guess it should be done here. However, other than within Periods, I doubt if it gives valuable feedback -->
                        </element>
                        <xsl:if test="f:*/f:extension">
                            <element id="{$elementId}.resource.extension">
                                <path value="{$path}.resource.extension"/>
                                <slicing>
                                    <discriminator>
                                        <type value="value"/>
                                        <path value="url"/>
                                    </discriminator>
                                    <rules value="open"/>
                                </slicing>
                                <min value="{count(f:*/f:extension)}"/>
                            </element>
                        </xsl:if>
                        <xsl:apply-templates select="f:*/f:*">
                            <xsl:with-param name="elementId" select="concat($elementId, '.resource')"/>
                            <xsl:with-param name="path" select="concat($path, '.resource')"/>
                            <xsl:with-param name="type" select="$resourceType" tunnel="yes"/>
                            <xsl:with-param name="structureDefinition" select="$structureDefinition" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:otherwise>
                </xsl:choose>
            </differential>
        </StructureDefinition>
    </xsl:template>
    
    <xsl:template match="f:Bundle/f:type">
        <xsl:param name="elementId"/>
        <element id="{nf:constructIdOrPath(., $elementId)}">
            <path value="Bundle.type"/>
            <fixedCode value="{@value}"/>
        </element>
    </xsl:template>
    
    <xsl:template match="f:Bundle/f:entry">
        <xsl:param name="elementId"/>
        <xsl:param name="path"/>
        
        <xsl:variable name="sliceName" select="lower-case(f:resource/f:*/local-name())"/>
        
        <!-- Process all entries? Or the ones selected by some nts:generateProfile attribute? -->
        <xsl:if test="not(preceding-sibling::f:entry)">
            <element id="{nf:constructIdOrPath(., $elementId)}">
                <path value="{nf:constructIdOrPath(., $path)}"/>
                <slicing>
                    <discriminator>
                        <type value="profile"/>
                        <path value="resource"/>
                    </discriminator>
                    <rules value="open"/>
                </slicing>
            </element>
            <element id="{nf:constructIdOrPath(., $elementId)}:{$sliceName}">
                <path value="Bundle.entry"/>
                <sliceName value="{$sliceName}"/>
                <min value="1"/>
                <max value="1"/>
            </element>
            
            <xsl:apply-templates select="*">
                <xsl:with-param name="elementId" select="concat(nf:constructIdOrPath(., $elementId),':',$sliceName)"/>
                <xsl:with-param name="path" select="nf:constructIdOrPath(., $path)"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>
    
    <!-- We can move the common assert here. For know: do nothing. -->
    <xsl:template match="f:Bundle/f:entry/f:fullUrl"/>
    <!-- Lets think of some checks to do matching Bundle type to this, but silencing it for now -->
    <xsl:template match="f:Bundle/f:entry/f:request"/>
    
    <xsl:template match="f:Bundle/f:entry/f:resource">
        <xsl:param name="elementId"/>
        <xsl:param name="path"/>
        
        <xsl:variable name="elementIdNew" select="nf:constructIdOrPath(., $elementId)"/>
        <xsl:variable name="pathNew" select="nf:constructIdOrPath(., $path)"/>
        <xsl:variable name="profile" select="f:*/f:meta/f:profile[1]/@value"/>
        <xsl:variable name="structureDefinition">
            <xsl:call-template name="getStructureDefinition">
                <xsl:with-param name="profile" select="$profile"/>
            </xsl:call-template>
        </xsl:variable>
        
        <element id="{$elementIdNew}">
            <path value="{$pathNew}"/>
            <min value="1"/>
            <type>
                <code value="Resource"/>
                <profile value="{$profile}"/>
            </type>
        </element>
        
        <!-- Skip the resourcetype element, we do not have anything to do there when starting from a Bundle -->
        <xsl:apply-templates select="f:*/f:*">
            <xsl:with-param name="elementId" select="$elementIdNew"/>
            <xsl:with-param name="path" select="$pathNew"/>
            <!-- This is a shortcut, we assume the child of f:resource is always an element with the same name as its resourceType. Type will stay the same up to the point that we want to dive into BackboneElements, extensions and/or datatype profiles -->
            <xsl:with-param name="type" select="f:*/local-name()" tunnel="yes"/>
            <xsl:with-param name="structureDefinition" select="$structureDefinition" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <!-- Here we start the real work -->
    <xsl:template match="f:*">
        <xsl:param name="elementId"/>
        <xsl:param name="path"/>
        <xsl:param name="type" tunnel="yes"/>
        <xsl:param name="url"/>
        
        <xsl:variable name="pathNew" select="nf:constructIdOrPath(., $path)"/>
        
        <!-- We get the corresponding elementDefinition here, because it is used multiple times in templates after this one. -->
        <xsl:variable name="elementDefinition">
            <xsl:call-template name="getElementDefinitions">
                <xsl:with-param name="path" select="$pathNew"/>
                <xsl:with-param name="parentPath" select="$path"/>
                <xsl:with-param name="parentType" select="$type"/>
                <xsl:with-param name="url" select="$url"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="elementType">
            <xsl:call-template name="getElementType">
                <xsl:with-param name="elementDefinition" select="$elementDefinition"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="isSliced" as="xs:boolean">
            <xsl:call-template name="checkSlicing">
                <xsl:with-param name="elementDefinition" select="$elementDefinition"/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- The element id takes significant effort, while its only use should be for identification. Would it be possible to fill it with some other random value? Then we can concentrate on the path, which is actually used. Looking at the definition: https://www.hl7.org/fhir/R4/element-definitions.html#Element.id this seems to be true, but actually I doubt if this will work. Constraints on sliced subelements only work because their .id refers to which slice the constraint belongs to. -->
        <xsl:variable name="elementIdNew" select="nf:constructIdOrPath(., $elementId)"/>
        
        <!-- Determine which action to take based on elementType -->
        <xsl:choose>
            <xsl:when test="$elementType = ('code','decimal', 'positiveInt', 'string', 'uri')">
                <element id="{$elementIdNew}">
                    <path value="{$pathNew}"/>
                    <min value="1"/>
                    <xsl:element name="fixed{concat(upper-case(substring($elementType,1,1)),
                        substring($elementType, 2))}">
                        <xsl:attribute name="value" select="@value"/>
                    </xsl:element>
                </element>
            </xsl:when>
            
            <xsl:when test="$elementType = ('BackboneElement', 'Dosage', 'Quantity', 'Timing') or ($elementType = 'Element' and (ends-with($pathNew, 'timing.repeat') or ends-with($pathNew, '.doseAndRate')))">
                <!-- 'Element' is the base of all elements, so not sure why .repeat has this type, therefore coupling it with a path check -->
                <element id="{$elementIdNew}">
                    <path value="{$pathNew}"/>
                    <min value="1"/>
                </element>
                <!-- Go one step deeper -->
                <xsl:apply-templates select="f:*">
                    <xsl:with-param name="elementId" select="$elementIdNew"/>
                    <xsl:with-param name="path" select="$pathNew"/>
                    <xsl:with-param name="type" tunnel="yes">
                        <xsl:choose>
                            <!-- These are too generic to pass forward -->
                            <xsl:when test="$elementType = ('BackboneElement','Element')">
                                <xsl:value-of select="concat($type, '.', local-name())"/>
                            </xsl:when>
                            <xsl:when test="$elementType = 'Timing'">
                                <!-- Looks like Timing as a whole is already defined within the SD of Dosage, so apparently no need to treat it as a separate datatype -->
                                <xsl:value-of select="concat($type, '.', local-name())"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$elementType"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                </xsl:apply-templates>
            </xsl:when>
            
            <xsl:when test="$elementType = 'CodeableConcept'">
                <xsl:choose>
                    <xsl:when test="f:coding">
                        <!-- Slice on coding, to allow other codings then the ones we 'prescribe' to be present
                        What happens when there is already slicing present? I guess we can check for that using structureDefinition ... See 'Reference' for a way to do that. -->
                        <element id="{$elementIdNew}">
                            <path value="{$pathNew}"/>
                            <min value="1"/>
                        </element>
                        <element id="{$elementIdNew}.coding">
                            <path value="{$pathNew}.coding"/>
                            <slicing>
                                <discriminator>
                                    <type value="value"/>
                                    <path value="code"/>
                                </discriminator>
                                <discriminator>
                                    <type value="value"/>
                                    <path value="system"/>
                                </discriminator>
                                <rules value="open"/>
                            </slicing>
                            <min value="{count(f:coding)}"/>
                        </element>
                        <xsl:for-each select="f:coding">
                            <!-- Instead of 'requiredCoding', make it something more meaningful like 'requiredCategoryCoding'? -->
                            <xsl:variable name="sliceName" select="string-join(('requiredCoding',if (count(preceding-sibling::f:coding) ne 0) then count(preceding-sibling::f:coding) + 1 else ''),'')"/>
                            <xsl:variable name="elementIdFull" select="concat($elementIdNew, '.coding:', $sliceName)"/>
                            <xsl:variable name="pathFull" select="concat($pathNew, '.coding')"/>
                            
                            <element id="{$elementIdFull}">
                                <path value="{$pathFull}"/>
                                <sliceName value="{$sliceName}"/>
                                <min value="1"/>
                                <max value="1"/>
                            </element>
                            <element id="{$elementIdFull}.system">
                                <path value="{$pathFull}.system"/>
                                <min value="1"/>
                                <fixedUri value="{f:system/@value}"/>
                            </element>
                            <element id="{$elementIdFull}.code">
                                <path value="{$pathFull}.code"/>
                                <min value="1"/>
                                <fixedCode value="{f:code/@value}"/>
                            </element>
                            <!-- Also check for display contents? Maybe by constraint (regex). But doesn't the validator do this already? -->
                            <element id="{$elementIdFull}.display">
                                <path value="{$pathFull}.display"/>
                                <min value="1"/>
                            </element>
                        </xsl:for-each>
                        <!-- f:text? -->
                    </xsl:when>
                    <xsl:when test="f:text">
                        <element id="{$elementIdNew}.text">
                            <path value="{$pathNew}.text"/>
                            <fixedString value="{f:text/@value}"/>
                        </element>
                    </xsl:when>
                </xsl:choose>
            </xsl:when>
            
            <xsl:when test="$elementType = 'dateTime'">
                <!-- Do some T-date magic here? Check for Time pattern with constraint/regex? How to handle time zones? -->
                <!-- T-dates in profiles not possible. -->
                <!-- Time pattern in regex: .toString().matches('T\\d{2}:\\d{2}:\\d{2}') -->
                <!-- Can we check for exact times? Only if timezones match. But shouldn't we check for timezones as well? .toString().matches('T23:59:59\\+0[12]:00') -->
            </xsl:when>
            <xsl:when test="$elementType = 'Identifier'">
                <element id="{$elementIdNew}">
                    <path value="{$pathNew}"/>
                    <min value="1"/>
                </element>
                <element id="{$elementIdNew}.system">
                    <path value="{$pathNew}.system"/>
                    <min value="1"/>
                </element>
                <element id="{$elementIdNew}.value">
                    <path value="{$pathNew}.value"/>
                    <min value="1"/>
                </element>
                <!-- We could also check the contents of .system and .value more, like we do with a common assert at the moment. -->
            </xsl:when>
            <xsl:when test="$elementType = 'Meta'">
                <!-- Check meta.profile? This is done by common assert at the moment. -->
            </xsl:when>
            <xsl:when test="$elementType = 'Reference'">
                <xsl:variable name="targetProfile">
                    <!-- How can we determine correct targetProfile? Some 'resolveReference' function that searches for the file and checks that for Meta.profile? Up to that point: try to get away by using .type -->
                    <xsl:variable name="type" select="f:type/@value"/>
                    <xsl:text>http://nictiz.nl/fhir/StructureDefinition/nl-core-</xsl:text>
                    <xsl:choose>
                        <xsl:when test="$type = 'Medication'">PharmaceuticalProduct</xsl:when>
                        <xsl:when test="$type = 'Organization'">HealthcareProvider-Organization</xsl:when>
                        <xsl:when test="$type = 'Patient'">Patient</xsl:when>
                        <xsl:when test="$type = 'PractitionerRole'">HealthProfessional</xsl:when>
                        <xsl:otherwise>
                            <xsl:message terminate="yes">Need a Reference targetProfile for <xsl:value-of select="$type"/></xsl:message>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="sliceName">
                    <xsl:if test="$isSliced">
                        <xsl:value-of select="$elementDefinition/f:element[f:type/f:targetProfile/@value = $targetProfile]/f:sliceName/@value"/>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="constrainTargetProfile" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="$isSliced and count($elementDefinition/f:element[f:sliceName/@value = $sliceName]/f:type/f:targetProfile) gt 1">
                            <xsl:value-of select="true()"/>
                        </xsl:when>
                        <xsl:when test="not($isSliced) and count($elementDefinition/f:element/f:type/f:targetProfile) gt 1">
                            <xsl:value-of select="true()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="false()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="elementIdFull" select="if (string-length($sliceName) gt 0) then concat($elementIdNew,':',$sliceName) else $elementIdNew "/>
                
                <!-- If the elementDefinition contains multiple targetProfiles, we can constrain the element further by only allowing 1 targetProfile. If the elementDefinition only contains 1 targetProfile, there is no need. 
                Also, if the element is sliced, we need to add this element -->
                <xsl:if test="$constrainTargetProfile or $isSliced">
                    <element id="{$elementIdFull}">
                        <path value="{$pathNew}"/>
                        <xsl:if test="$isSliced">
                            <sliceName value="{$sliceName}"/>
                        </xsl:if>
                        <xsl:if test="$constrainTargetProfile">
                            <type>
                                <code value="Reference"/>
                                <targetProfile value="{$targetProfile}"/>
                            </type>
                        </xsl:if>
                    </element>
                </xsl:if>
                
                <element id="{$elementIdFull}.reference">
                    <path value="{$pathNew}.reference"/>
                    <min value="1"/>
                </element>
                <element id="{$elementIdFull}.type">
                    <path value="{$pathNew}.type"/>
                    <min value="1"/>
                    <fixedUri value="{f:type/@value}"/>
                </element>
                <element id="{$elementIdFull}.display">
                    <path value="{$pathNew}.display"/>
                    <min value="1"/>
                </element>
            </xsl:when>
            
            <!-- Resource.id seems to use a special elementType code. Putting in an extra ends-with a) just to be sure and b) because we really would do like a 'special' check on .id, not just some string check. At the moment this is already checked by a common assert however. -->
            <xsl:when test="$elementType = 'http://hl7.org/fhirpath/System.String' and ends-with($pathNew, '.id')"/>
            
            <xsl:when test="$elementType = 'Extension'">
                <xsl:variable name="url" select="@url"/>
                <xsl:variable name="sliceName" select="$elementDefinition/f:element[f:type/f:profile/@value = $url]/f:sliceName/@value"/>
                <xsl:variable name="elementIdFull" select="concat($elementIdNew, ':', $sliceName)"/>
                <element id="{$elementIdFull}">
                    <path value="{$pathNew}"/>
                    <sliceName value="{$sliceName}"/>
                    <min value="1"/>
                    <max value="1"/>
                </element>
                <xsl:apply-templates select="f:*">
                    <xsl:with-param name="elementId" select="$elementIdFull"/>
                    <xsl:with-param name="path" select="$pathNew"/>
                    <xsl:with-param name="type" select="$elementType" tunnel="yes"/>
                    <xsl:with-param name="url" select="$url"/>
                </xsl:apply-templates>
            </xsl:when>
            
            <xsl:when test="$elementType = 'Period'">
                <element id="{$elementIdNew}">
                    <path value="{$pathNew}"/>
                    <min value="1"/>
                    <constraint>
                        <key value="ma1"/>
                        <severity value="error"/>
                        <human value="Period.start and Period.end must have a difference of 9 days, 23:59:59"/>
                        <expression value="start + 9 days + 23 hours + 59 minutes + 59 seconds = end"/>
                    </constraint>
                    <constraint>
                        <key value="ma2"/>
                        <severity value="error"/>
                        <human value="Check if T-date works"/>
                        <expression value="start = @${{DATE, T, D, -4}}T00:00:00+02:00"/>
                    </constraint>
                </element>
                <!-- Should just refer to dateTime? Guess so -->
                <!--<xsl:if test="f:start">
                    <element id="{$elementIdNew}.start">
                        <path value="{$pathNew}.start"/>
                        <min value="1"/>
                        <fixedDateTime value="{f:start/@value}"/>
                    </element>
                </xsl:if>-->
                <!--<xsl:if test="f:end">
                    <element id="{$elementIdNew}.end">
                        <path value="{$pathNew}.end"/>
                        <min value="1"/>
                        <fixedDateTime value="2022-09-10T23:59:59+02:00"/>
                    </element>
                </xsl:if>-->
            </xsl:when>
            
            <xsl:otherwise>
                <!--<debug>
                    <xsl:copy-of select="."/>
                </debug>-->
                <!--<debug>
                    <xsl:copy-of select="$elementDefinition"/>
                </debug>-->
                <xsl:message terminate="yes">Unknown elementType: <xsl:value-of select="$elementType"/></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
        
        <!--<debug>
            <xsl:copy-of select="$elementDefinition"/>
        </debug>-->
    </xsl:template>
    
    <!-- Construct element id or path by combining the 'inherited' id/path and the local element. Main goal is to detect and process choice (polymorphic) elements.
    Element id differs from path in that it also contains slicenames. These are added to the 'inherited' input param if applicable-->
    <xsl:function name="nf:constructIdOrPath">
        <xsl:param name="in"/>
        <xsl:param name="inherited"/>
        
        <xsl:variable name="local">
            <xsl:if test="$inherited">
                <xsl:text>.</xsl:text>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="nf:isChoiceElement($in/local-name())">
                    <xsl:value-of select="nf:createChoiceElement($in/local-name())"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$in/local-name()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:value-of select="concat($inherited, $local)"/>
    </xsl:function>
    
    <!-- Returns true or false if a choice element is deteced. Contains some hard coded overrides ('postalCode'), maybe there are more. -->
    <xsl:function name="nf:isChoiceElement" as="xs:boolean">
        <xsl:param name="path" as="xs:string"/>
        <xsl:variable name="datatypes" select="('Address','Annotation','Attachment','Boolean','CodeableConcept','Coding','Code','ContactPoint','Count','Date','DateTime','Decimal','Dosage','HumanName','Identifier','Integer','Period','SimpleQuantity','Quantity','Age','Distance','Duration','Money','Ratio','Reference','SampledData','String','Time','Timing','Uri')"/>
        
        <xsl:choose>
            <xsl:when test="ends-with($path,'postalCode')">
                <xsl:value-of select="false()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="some $datatype in $datatypes satisfies ends-with($path, $datatype)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- When given a string, returns the portion of the string before a FHIR datatype and adds '[x]'. -->
    <xsl:function name="nf:createChoiceElement" as="xs:string">
        <xsl:param name="path" as="xs:string"/>
        <xsl:variable name="valuePath">
            <xsl:choose>
                <xsl:when test="ends-with($path,'Address')">
                    <xsl:value-of select="substring-before($path,'Address')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Annotation')">
                    <xsl:value-of select="substring-before($path,'Annotation')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Attachment')">
                    <xsl:value-of select="substring-before($path,'Attachment')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Boolean')">
                    <xsl:value-of select="substring-before($path,'Boolean')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'CodeableConcept')">
                    <xsl:value-of select="substring-before($path,'CodeableConcept')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Coding')">
                    <xsl:value-of select="substring-before($path,'Coding')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Code')">
                    <xsl:value-of select="substring-before($path,'Code')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'ContactPoint')">
                    <xsl:value-of select="substring-before($path,'ContactPoint')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Count')">
                    <xsl:value-of select="substring-before($path,'Count')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Date')">
                    <xsl:value-of select="substring-before($path,'Date')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'DateTime')">
                    <xsl:value-of select="substring-before($path,'DateTime')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Decimal')">
                    <xsl:value-of select="substring-before($path,'Decimal')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Dosage')">
                    <xsl:value-of select="substring-before($path,'Dosage')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'HumanName')">
                    <xsl:value-of select="substring-before($path,'HumanName')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Identifier')">
                    <xsl:value-of select="substring-before($path,'Identifier')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Integer')">
                    <xsl:value-of select="substring-before($path,'Integer')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Period')">
                    <xsl:value-of select="substring-before($path,'Period')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Quantity')">
                    <xsl:value-of select="substring-before($path,'Quantity')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Age')">
                    <xsl:value-of select="substring-before($path,'Age')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Distance')">
                    <xsl:value-of select="substring-before($path,'Distance')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Duration')">
                    <xsl:value-of select="substring-before($path,'Duration')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Money')">
                    <xsl:value-of select="substring-before($path,'Money')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'SimpleQuantity')">
                    <xsl:value-of select="substring-before($path,'SimpleQuantity')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Ratio')">
                    <xsl:value-of select="substring-before($path,'Ratio')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Reference')">
                    <xsl:value-of select="substring-before($path,'Reference')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'SampledData')">
                    <xsl:value-of select="substring-before($path,'SampledData')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'String')">
                    <xsl:value-of select="substring-before($path,'String')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Time')">
                    <xsl:value-of select="substring-before($path,'Time')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Timing')">
                    <xsl:value-of select="substring-before($path,'Timing')"/>
                </xsl:when>
                <xsl:when test="ends-with($path,'Uri')">
                    <xsl:value-of select="substring-before($path,'Uri')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$path"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="concat($valuePath,'[x]')"/>
    </xsl:function>
    
    <!-- Resolves a canonical in scope of a package at Simplifier, loads the resulting page as unparsed text and then regexes the page to search for the 'download snapshot' link. If anything changes at Simplifier, we should look at this one.-->
    <xsl:template name="getStructureDefinition">
        <xsl:param name="profile" select="f:meta/f:profile/@value"/>
        
        <xsl:variable name="packageFileId">
            <xsl:analyze-string select="unparsed-text(concat('https://simplifier.net/resolve?scope=',$fhirPackage,'@',$fhirPackageVersion,'&amp;canonical=',$profile))" regex="[/]ui[/]packagefile[/]downloadsnapshotas[?]packageFileId=([0-9]{{5,6}})[&amp;]amp;format=xml">
                <xsl:matching-substring>
                    <xsl:copy-of select="regex-group(1)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:if test="$debug">
            <xsl:message>profile: <xsl:value-of select="$profile"/> - packageFileId: '<xsl:value-of select="$packageFileId"/>'</xsl:message>
        </xsl:if>
        
        <xsl:variable name="rawStructureDefinitions">
            <xsl:choose>
                <xsl:when test="string-length($packageFileId) gt 0">
                    <xsl:variable name="structureDefinition" select="document(concat('https://simplifier.net/ui/packagefile/downloadsnapshotas?packageFileId=',$packageFileId,'&amp;format=xml'))"/>
                    <!-- We add packageFileId to deduplicate -->
                    <StructureDefinition packageFileId="{$packageFileId}">
                        <xsl:copy-of select="$structureDefinition/f:StructureDefinition/*"/>
                    </StructureDefinition>
                    
                    <!-- Add StructureDefinitions of referenced datatype and extension profiles. For example: when no differential is present when dealing with a type profile, no SD-info is available in the snapshot (nl-core-patient, Patient.address for example). So we should add these to the set of SDs -->
                    <xsl:for-each select="distinct-values($structureDefinition//f:element/f:type/f:profile/@value)">
                        <xsl:call-template name="getStructureDefinition">
                            <xsl:with-param name="profile" select="."/>
                        </xsl:call-template>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">Unable to download snapshot for profile '<xsl:value-of select="$profile"/>'</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- Filtering unique SDs by packageFileId. Perhaps this can be done more efficiently _before_ calling Simplifier? -->
        <xsl:copy-of select="$rawStructureDefinitions/f:StructureDefinition[not(@packageFileId = preceding-sibling::f:StructureDefinition/@packageFileId)]"/>
    </xsl:template>
    
    <!-- For a given element.path, get it's element type. -->
    <xsl:template name="getElementType">
        <xsl:param name="elementDefinition" required="yes"/>
        
        <!-- The type seems to be the same in all elementDefinitions present, so we pick the first one. Have yet to encounter situations where this isn't the case. If the element is a polymorphic element, there are multiple .type's, so we have to check which one is applicable -->
        <xsl:variable name="elementType">
            <xsl:choose>
                <xsl:when test="count(($elementDefinition/f:element)[1]/f:type) = 1">
                    <xsl:value-of select="($elementDefinition/f:element)[1]/f:type/f:code/@value"/>
                </xsl:when>
                <xsl:when test="nf:isChoiceElement(local-name()) and count(($elementDefinition/f:element)[1]/f:type) gt 1">
                    <xsl:variable name="elementTypeByLocalName" select="substring-after(local-name(), substring-before(nf:createChoiceElement(local-name()), '[x]'))"/>
                    <xsl:value-of select="($elementDefinition/f:element)[1]/f:type/f:code[@value = $elementTypeByLocalName]/@value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">Unknown situation when determining elementType</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:if test="$debug">
            <xsl:message select="concat('elementType: ',$elementType)"/>
        </xsl:if>
        <xsl:value-of select="$elementType"/>
        
    </xsl:template>
    
    <!-- For a given element.path, check if the element is sliced in the profile this resources is based on. If not, we can create our own slice for the checks we want to do. Otherwise, we have to use the existing slice and its properties -->
    <xsl:template name="checkSlicing">
        <xsl:param name="elementDefinition" required="yes"/>
        
        <xsl:choose>
            <xsl:when test="$elementDefinition/f:element/f:slicing">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- For a given element.path, search the given set of StructureDefintions for a match and returns ElementDefinition for that match.
    If no match is found, part of the path is replaced by parentType to search again. Example: no match will probably be found for 'Bundle.entry.resource.identifier', if we replace 'Bundle.entry.resource' with the resourceType, it will probably result in a match.
    
    This can result in multiple ElementDefinitions being found because of slicing. Logic to determine which one is needed should be in place later. 
    -->
    <xsl:template name="getElementDefinitions" as="element(f:element)*">
        <xsl:param name="structureDefinition" tunnel="yes" required="yes"/>
        <xsl:param name="path" required="yes"/>
        <xsl:param name="parentPath"/>
        <xsl:param name="parentType"/>
        <xsl:param name="url"/>
        
        <!-- Because replace() is regex, we need to escape dots and polymorphic brackets -->
        <xsl:param name="parentPathRegex" as="xs:string?">
            <xsl:value-of select="replace(replace(replace($parentPath, '\.', '\\.'), '\[', '\\['), '\]', '\\]')"/>
        </xsl:param>
        
        <xsl:if test="$debug">
            <xsl:message select="concat('getElementDefinitions: path = ',$path, ' - parentPath = ', $parentPath, ' - parentType = ', $parentType, ' - replaced = ',replace($path, $parentPath, $parentType))"/>
        </xsl:if>
        
        <xsl:choose>
            <!-- If the element is in an extension, $url is present and we should it account (because 'Extension.value[x]' will probably give multiple matches -->
            <xsl:when test="string-length($url) gt 0 and $structureDefinition/f:StructureDefinition/f:snapshot[f:element[@id = 'Extension.url']/f:fixedUri/@value = $url]/f:element[f:path/@value = replace($path, $parentPathRegex, $parentType)]">
                <xsl:if test="$debug">
                    <xsl:message select="concat('Found extension path: ', replace($path, $parentPathRegex, $parentType))"/>
                </xsl:if>
                <xsl:copy-of select="$structureDefinition/f:StructureDefinition/f:snapshot[f:element[@id = 'Extension.url']/f:fixedUri/@value = $url]/f:element[f:path/@value = replace($path, $parentPathRegex, $parentType)]"/>
            </xsl:when>
            <!-- If it is not an extension, first we just try to find if 'it' is there -->
            <xsl:when test="string-length($url) = 0 and $structureDefinition/f:StructureDefinition/f:snapshot/f:element/f:path/@value = $path">
                <xsl:if test="$debug">
                    <xsl:message select="concat('Found path: ', $path)"/>
                </xsl:if>
                <xsl:copy-of select="$structureDefinition/f:StructureDefinition/f:snapshot/f:element[f:path/@value = $path]"/>
            </xsl:when>
            <!-- Then, we try to replace the path of the element's parent with the type of that parent and try again -->
            <xsl:when test="string-length($url) = 0 and $parentPath and $structureDefinition/f:StructureDefinition/f:snapshot/f:element/f:path/@value = replace($path, $parentPathRegex, $parentType)">
                <xsl:if test="$debug">
                    <xsl:message select="concat('Found path: ', replace($path, $parentPathRegex, $parentType))"/>
                </xsl:if>
                <xsl:copy-of select="$structureDefinition/f:StructureDefinition/f:snapshot/f:element[f:path/@value = replace($path, $parentPathRegex, $parentType)]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">Could not find elementDefinition for <xsl:value-of select="$path"/> <xsl:value-of select="$url"/></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>