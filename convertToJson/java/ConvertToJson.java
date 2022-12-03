import ca.uhn.fhir.context.FhirContext;
import ca.uhn.fhir.parser.IParser;

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ConvertToJson {
    
    private static String loadMaskedXML(String filePath, List<String> dtPlaceholders) {
        // First, load the raw XML
        String XML;
        try {
            XML = Files.readString(Path.of(filePath));
        } catch (IOException e) {
            System.err.println(e.toString());
            return "";
        }

        // Collect and then replace all the datetime placeholders.
        Pattern dtPlaceholderPattern = Pattern.compile("\\$\\{(CURRENT)?DATE.*?\\}");
        Matcher dtPlaceholderMatcher = dtPlaceholderPattern.matcher(XML);
        while (dtPlaceholderMatcher.find()) {
            dtPlaceholders.add(dtPlaceholderMatcher.group());
        }

        // Now replace all datetime placeholders with our known pattern.
        XML = dtPlaceholderMatcher.replaceAll("0001-01-01");
        return XML;
    }

    private static String unmaskJSON(String maskedJSON, List<String> dtPlaceholders) {
        // And restore all placeholders
        String unmaskedJSON = "";
        Pattern dtMaskPattern = Pattern.compile("0001-01-01");
        Matcher dtMaskMatcher = dtMaskPattern.matcher(maskedJSON);
        int pos = 0;
        int placeholderNum = 0;
        while (dtMaskMatcher.find()) {
            unmaskedJSON += maskedJSON.substring(pos, dtMaskMatcher.start()) + dtPlaceholders.get(placeholderNum);
            pos = dtMaskMatcher.end();
        }
        unmaskedJSON += maskedJSON.substring(pos);
        return unmaskedJSON;
    }

    public static void main(String[] args) {
        String version = args[0];

        String fileList;
        try {
            fileList = Files.readString(Path.of(args[1]));
        } catch (IOException e) {
            System.err.println(e.toString());
            System.err.println("File containing the list of fixtures to convert couldn't be read.");
            return;
        }

        Object xmlParser = null;
        FhirContext context = null;
        if (version.equals("STU3")) {
            context = FhirContext.forDstu3();
            xmlParser = new org.hl7.fhir.dstu3.formats.XmlParser();
        } else if (version.equals("R4")) {
            context = FhirContext.forR4();
            xmlParser = new org.hl7.fhir.r4.formats.XmlParser();
        }
        
        IParser jsonParser = context.newJsonParser();
        jsonParser.setPrettyPrint(true);

        String[] fixtures = fileList.split(" ");
        for (String fixture: fixtures) {
            List<String>dtPlaceholders = new ArrayList<String>();
            String XML = loadMaskedXML(fixture, dtPlaceholders);
            String JSON = "";
            try {
                if (version.equals("STU3")) {
                    org.hl7.fhir.dstu3.model.Resource resource = ((org.hl7.fhir.dstu3.formats.XmlParser)xmlParser).parse(XML);
                    JSON = jsonParser.encodeResourceToString(resource);
                } else if (version.equals("R4")) {
                    org.hl7.fhir.r4.model.Resource resource = ((org.hl7.fhir.r4.formats.XmlParser)xmlParser).parse(XML);
                    JSON = jsonParser.encodeResourceToString(resource);
                }
            } catch (IOException e) {
                System.out.print("Input file could not be parsed: " + fixture);
                return;
            }
            JSON = unmaskJSON(JSON, dtPlaceholders);
    
            // And write the result to disk
            String base_name = fixture.substring(0, fixture.lastIndexOf("."));
            String out_path = base_name + ".json";
            try {
                FileWriter jsonWriter = new FileWriter(out_path);
                jsonWriter.write(JSON);
                jsonWriter.close();
            } catch (IOException e) {
                System.out.print("Output file could not be opened: " + out_path);
            }

            System.out.println("Converted fixture " + fixture + " to JSON");
        }
    }
}
