import java.io.BufferedWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.apache.lucene.document.Document;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.MultiDocValues;
import org.apache.lucene.index.Term;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.search.TermQuery;
import org.apache.lucene.store.FSDirectory;

/** Exports the stored pages of exactly one Shamela book as UTF-8 JSON Lines. */
public final class ShamelaPageExporter {
  private record Page(long pageId, long printedPage, String body) {}

  private ShamelaPageExporter() {}

  public static void main(String[] args) throws Exception {
    if (args.length != 3) {
      System.err.println("Usage: ShamelaPageExporter <page-index> <book-id> <output.jsonl>");
      System.exit(2);
    }

    Path indexPath = Path.of(args[0]);
    String bookId = args[1];
    Path outputPath = Path.of(args[2]);
    List<Page> pages = new ArrayList<>();

    try (var directory = FSDirectory.open(indexPath);
         var reader = DirectoryReader.open(directory)) {
      var searcher = new IndexSearcher(reader);
      var query = new TermQuery(new Term("book_key", bookId));
      int count = searcher.count(query);
      if (count == 0) {
        System.err.println("No indexed pages found for Shamela book " + bookId);
        System.exit(3);
      }

      var books = MultiDocValues.getNumericValues(reader, "book");
      var printedPages = MultiDocValues.getNumericValues(reader, "page");
      for (var hit : searcher.search(query, count).scoreDocs) {
        if (books == null || !books.advanceExact(hit.doc)
            || books.longValue() != Long.parseLong(bookId)) {
          throw new IllegalStateException("Lucene returned a page from a different book");
        }
        Document document = reader.storedFields().document(hit.doc);
        String storedId = document.get("id");
        String body = document.get("body");
        if (storedId == null || body == null || body.isBlank()) continue;
        int separator = storedId.indexOf('-');
        if (separator < 1 || !storedId.substring(0, separator).equals(bookId)) {
          throw new IllegalStateException("Unexpected stored page id: " + storedId);
        }
        long pageId = Long.parseLong(storedId.substring(separator + 1));
        long printedPage = printedPages != null && printedPages.advanceExact(hit.doc)
            ? printedPages.longValue() : -1;
        pages.add(new Page(pageId, printedPage, body.strip()));
      }
    }

    pages.sort(Comparator.comparingLong(Page::pageId));
    Files.createDirectories(outputPath.getParent());
    try (BufferedWriter writer = Files.newBufferedWriter(outputPath, StandardCharsets.UTF_8)) {
      for (Page page : pages) {
        writer.write("{\"page_id\":" + page.pageId()
            + ",\"printed_page\":" + page.printedPage()
            + ",\"text\":\"" + escapeJson(page.body()) + "\"}");
        writer.newLine();
      }
    }
    System.out.println("Exported " + pages.size() + " pages for Shamela book " + bookId);
  }

  private static String escapeJson(String value) {
    StringBuilder escaped = new StringBuilder(value.length() + 32);
    for (int i = 0; i < value.length(); i++) {
      char character = value.charAt(i);
      switch (character) {
        case '\\' -> escaped.append("\\\\");
        case '"' -> escaped.append("\\\"");
        case '\n' -> escaped.append("\\n");
        case '\r' -> escaped.append("\\r");
        case '\t' -> escaped.append("\\t");
        default -> {
          if (character < 0x20) {
            escaped.append(String.format("\\u%04x", (int) character));
          } else {
            escaped.append(character);
          }
        }
      }
    }
    return escaped.toString();
  }
}
