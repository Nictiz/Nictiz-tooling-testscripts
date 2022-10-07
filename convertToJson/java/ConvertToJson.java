import ca.uhn.fhir.context.FhirContext;
// import org.hl7.fhir.dstu3.formats.IParser;
import ca.uhn.fhir.parser.IParser;
import org.hl7.fhir.dstu3.formats.XmlParser;
// import org.hl7.fhir.dstu3.formats.JsonParser;
// import org.hl7.fhir.r4.model.Bundle;
import org.hl7.fhir.dstu3.model.Bundle;

import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;

public class ConvertToJson {

    private static void convertBundle(String filePath, XmlParser xmlParser, IParser jsonParser) {
        Bundle bundle;

        try {
            InputStream in = new FileInputStream(filePath);
            bundle = (Bundle)xmlParser.parse(in);
            in.close();
        } catch (IOException e) {
            System.out.print("Input file not found: " + filePath);
            return;
        }

        String base_name = filePath.substring(0, filePath.lastIndexOf("."));
        String out_path = base_name + ".json";
        try {
            FileWriter jsonWriter = new FileWriter(out_path);
            jsonWriter.write(jsonParser.encodeResourceToString(bundle));
            jsonWriter.close();
        } catch (IOException e) {
            System.out.print("Output file could not be opened: " + out_path);
        }
    }

    public static void main(String[] args) {
        // FhirContext context = FhirContext.forR4();

        FhirContext context = FhirContext.forDstu3();

        // switch (args[1]) {
        //     case "STU3":
        //         context = FhirContext.forDstu3();
        //         break;
        //     case "R4":
        //         context = FhirContext.forR4();
        //         break;
        //     default:
        //         // No valid FHIR version, so return error
        //         // return 1;
        // }

        
        XmlParser xmlParser = new XmlParser();
        IParser jsonParser = context.newJsonParser();
        jsonParser.setPrettyPrint(true);

        for (int i = 1; i < args.length; i++) {
            convertBundle(args[i], xmlParser, jsonParser);
        }
    }
}