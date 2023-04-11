import url from "./urls";
import { get_csrf_token } from "../legacy/lib/helpers";

export const jurisdictions = [
    { val: "ala", name: "Alabama" },
    { val: "alaska", name: "Alaska" },
    { val: "am-samoa", name: "American Samoa" },
    { val: "ariz", name: "Arizona" },
    { val: "ark", name: "Arkansas" },
    { val: "cal", name: "California" },
    { val: "colo", name: "Colorado" },
    { val: "conn", name: "Connecticut" },
    { val: "dakota-territory", name: "Dakota Territory" },
    { val: "dc", name: "District of Columbia" },
    { val: "del", name: "Delaware" },
    { val: "fla", name: "Florida" },
    { val: "ga", name: "Georgia" },
    { val: "guam", name: "Guam" },
    { val: "haw", name: "Hawaii" },
    { val: "idaho", name: "Idaho" },
    { val: "ill", name: "Illinois" },
    { val: "ind", name: "Indiana" },
    { val: "iowa", name: "Iowa" },
    { val: "kan", name: "Kansas" },
    { val: "ky", name: "Kentucky" },
    { val: "la", name: "Louisiana" },
    { val: "mass", name: "Massachusetts" },
    { val: "md", name: "Maryland" },
    { val: "me", name: "Maine" },
    { val: "mich", name: "Michigan" },
    { val: "minn", name: "Minnesota" },
    { val: "miss", name: "Mississippi" },
    { val: "mo", name: "Missouri" },
    { val: "mont", name: "Montana" },
    { val: "native-american", name: "Native American" },
    { val: "navajo-nation", name: "Navajo Nation" },
    { val: "nc", name: "North Carolina" },
    { val: "nd", name: "North Dakota" },
    { val: "neb", name: "Nebraska" },
    { val: "nev", name: "Nevada" },
    { val: "nh", name: "New Hampshire" },
    { val: "nj", name: "New Jersey" },
    { val: "nm", name: "New Mexico" },
    { val: "n-mar-i", name: "Northern Mariana Islands" },
    { val: "ny", name: "New York" },
    { val: "ohio", name: "Ohio" },
    { val: "okla", name: "Oklahoma" },
    { val: "or", name: "Oregon" },
    { val: "pa", name: "Pennsylvania" },
    { val: "pr", name: "Puerto Rico" },
    { val: "ri", name: "Rhode Island" },
    { val: "sc", name: "South Carolina" },
    { val: "sd", name: "South Dakota" },
    { val: "tenn", name: "Tennessee" },
    { val: "tex", name: "Texas" },
    { val: "tribal", name: "Tribal jurisdictions" },
    { val: "uk", name: "United Kingdom" },
    { val: "us", name: "United States" },
    { val: "utah", name: "Utah" },
    { val: "va", name: "Virginia" },
    { val: "vi", name: "Virgin Islands" },
    { val: "vt", name: "Vermont" },
    { val: "wash", name: "Washington" },
    { val: "wis", name: "Wisconsin" },
    { val: "w-va", name: "West Virginia" },
    { val: "wyo", name: "Wyoming" },
  ];

/**
 * Accepts a query for a legal document and returns the result list
 *
 * @param {string} query the query to pass long to the search
 * @param {array} allSources all available sources
 * @param {?number} sourceId the id of the only source to query
 * @param {?string} jurisdiction code for the state/jurisdiction to limit the search
 * @param {?string} beforeDate YYYY-MM-DD date string
 * @param {?string} afterDate YYYY-MM-DD date string *
 *
 * @returns {array} the list of results by source
 */
export const search = async (
  query,
  allSources,
  sourceId,
  jurisdiction,
  beforeDate,
  afterDate
) => {
  const api = url.url("search_using");

  const sources = [];
  const sourceDetail = allSources.filter((s) =>
    sourceId ? s.id === sourceId : true
  );

  let order = 0; // Sources will come back ordered in "priority order", which we want to retain

  for (const { id, name } of sourceDetail) {
    const url =
      api({ sourceId: id }) +
      "?" +
      new URLSearchParams({
        q: query,
        jurisdiction: jurisdiction || "",
        before_date: beforeDate || "",
        after_date: afterDate || "",
      });
    sources.push({ url, id, name, order });
    order += 1;
  }
  return await Promise.all(
    sources.map(async (source) => {
      const { url, id, name, order } = source;
      const resp = await fetch(url);
      if (resp.ok) {
        const json = await resp.json()
        const { results } = json;
          return results.map((row) => {
            row.id = row.id.toString(); // normalize IDs from the API to strings
            return {
              name,
              sourceId: id,
              sourceOrder: order,
              ...row,
            };
        });
      }
      else {
        console.error(resp.status)
        return [{error: "The search is not currently working, but our team has been notified. Please retry later."}];
      }
    })
  );
};
/**
 * Given a casebook and optional section ID, add a legal document
 * from the identified source to the casebook and return the location of the 
 * resource in the book.
 * 
 * @param {string} casebookId the ID of the casebook
 * @param {?string} sectionId the optional ID of the section in which to nest it
 * @param {string} sourceRef the foreign identifier of the legal document
 * @param {number} sourceId the local identifier of the source (e.g. CAP)
 * 
 * @returns {Object}
 */
export const add = async (casebookId, sectionId, sourceRef, sourceId) => {
  const api = url.url("legal_document_resource_view");

  const resp = await fetch(api({ casebookId }), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": get_csrf_token(),
    },
    body: JSON.stringify({
      source_id: sourceId,
      source_ref: sourceRef,
      section_id: sectionId,
    }),
  });
  if (resp.ok) {
    const body = await resp.json();
    return {
      resourceId: body.resource_id,
      redirectUrl: body.redirect_url,
      sourceRef,
    };
  }
  else {
    console.error(resp.status);
    return {
      error: "The legal document could not be added because of an error. Our team has been notified. Please retry later."
    }
  }
};
