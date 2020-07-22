import _ from "lodash";
import urls from './urls';

const numeric_ending = /[0-9ivx]+$/;
const numeric_ending_stripper = /,?[ ….]*[0-9ivx]+$/;

// Some syllabi start with a "Chapter", "Part", or "Unit" stop word
const enumeration_stop_prefixes = ['chapter', 'unit', 'part'];

// Arabic, or roman numerals, or letters
const arabic = { test: /^[0-9]+$/, level: parseInt };
const roman = { test: /^[ivxl]+$/, level: roman_to_int };
const letter = { test: /^[a-z]$/, level: string => parseInt(string, 36) - 9 };
const enumeration_prefix_identifier = /^(([0-9]+|[a-z]|[ivxl]+)[.:)])+/;
const cuckoo_starts = /^(a[.]l[.]a[.]|u[.]s[.])/;
// Nesting delimiter, and termination character
const enumeration_delimiter = /[.:)]/;

function enumeration_identification(line) {
  let candidate = line.trim();
  let prefix_check = candidate.toLowerCase();
  let top = false;
  if (line.match(cuckoo_starts)) {
    return { numeral_stack: [], title: line };
  }
  for (let stop of enumeration_stop_prefixes) {
    if (prefix_check.startsWith(stop)) {
      top = true;
      prefix_check = prefix_check.substr(stop.length).trim();
    }
  }
  let prefixes = enumeration_prefix_identifier.exec(prefix_check);
  if (!prefixes) {
    return { numeral_stack: [], title: line };
  }
  let numeral_stack = [];

  for (let prefix of prefixes[0].split(enumeration_delimiter)) {
    numeral_stack.push({
      arabic: prefix.match(arabic.test) ? arabic.level(prefix) : -1,
      roman: prefix.match(roman.test) ? roman.level(prefix) : -1,
      letter: prefix.match(letter.test) ? letter.level(prefix) : -1
    });
  }
  if (top) {
    numeral_stack = numeral_stack.map(
      prefix => _.fromPairs(_.toPairs(prefix).map(x => ['top_' + x[0], x[1]]))
    );
  }
  numeral_stack.pop();
  const suffix_length = prefix_check.length - prefixes[0].length;
  let title = candidate.substr(candidate.length - suffix_length).trim();
  return { numeral_stack, title };
}

function starts_with_numeral(line) {
  return enumeration_identification(line).numeral_stack.length > 0;
}

function merge_wrapped_lines(lines) {
  // Check if the majority of lines end in numbers
  // If so, merge any lines that don't end in numbers into the previous line,
  // unless they start with one of the numeral prefixes above
  // This also strips the line endings (...XX) that generally point to no-longer-existent page numbers

  const line_count = lines.length;
  const numbered_line_count = lines.map(x => numeric_ending.test(x) ? 1 : 0).reduce((a, b) => a + b);
  if (2 * numbered_line_count < line_count) {
    return lines;
  }
  let merged_lines = [];
  let accumulated_line = "";
  for (let ii = 0; ii < line_count; ii++) {
    const current_line = lines[ii].trim();

    if (accumulated_line !== "" && starts_with_numeral(current_line)) {
      merged_lines.push(accumulated_line.replace(numeric_ending_stripper, "").trim());
      accumulated_line = "";
    }
    accumulated_line += current_line;
    if (numeric_ending.test(current_line)) {
      merged_lines.push(accumulated_line.replace(numeric_ending_stripper, "").trim());
      accumulated_line = "";
    } else {
      accumulated_line += " ";
    }
  }
  if (accumulated_line !== "") {
    merged_lines.push(accumulated_line);
  }
  return merged_lines;
}


function roman_to_int(string) {
  const char_to_int = { 'i': 1, 'v': 5, 'x': 10, 'l': 50, 'c': 100 };
  if (string == null) return -1;

  let num = char_to_int[string.charAt(0)];
  let pre, curr;

  for (var i = 1; i < string.length; i++) {
    curr = char_to_int[string.charAt(i)];
    pre = char_to_int[string.charAt(i - 1)];
    if (curr <= pre) {
      num += curr;
    } else {
      num = num - pre * 2 + curr;
    }
  }
  return num;
}

function guess_line_depth(lines) {
  let frontier = [];
  let guessed_lines = [];
  function to_depth(front) {
    return front.length;
  }

  function smallest_numeral(en) {
    return _.fromPairs([_.minBy(_.toPairs(en).filter(x => x[1] > -1), x => x[1])]);
  }

  function check_for_match(frontier, check, cond) {
    let test_frontier = frontier.slice();
    while (test_frontier.length > 0) {
      let top_test = test_frontier.pop();
      let top_type = _.keys(top_test)[0];
      if (cond(top_test[top_type], check[top_type])) {
        test_frontier.push(top_test);
        return test_frontier;
      }
    }
    return false;
  }

  function guess_a_line(frontier, line) {
    let { numeral_stack, title } = line;
    let new_line = { title };
    // Enum Stack has nothing on it
    // if the top of the frontier was a blank, this is next in line.
    // If the top of the frontier was numbered, this is a first child

    if (numeral_stack.length === 0) {
      if (frontier === []) {
        new_line.enum = [1];
        frontier = [{ blank: 1 }];
        return [frontier, new_line];
      }
      const last_frontier = frontier[frontier.length - 1] || { blank: 0 };
      if (last_frontier.blank) {
        last_frontier.blank += 1;
        new_line.depth = to_depth(frontier);
        return [frontier, new_line];
      } else {
        frontier.push({ blank: 1 });
        new_line.depth = to_depth(frontier);
        return [frontier, new_line];
      }
    }

    // Enum stack has one item
    if (numeral_stack.length === 1) {
      // If this is a top level section, clear out non-top frontier
      if (_.keys(numeral_stack[0])[0].startsWith('top_')) {
        try {
          frontier = frontier.filter(x => _.keys(x)[0].startsWith('top_'));
        } catch (error) {
          console.warn(error);
        }
      }
      // If this has a 1 value, it's a child of the current frontier
      let en = _.some(_.values(numeral_stack[0]), x => x === 1);
      if (en) {
        let o = smallest_numeral(numeral_stack[0]);
        frontier.push(o);
        new_line.depth = to_depth(frontier);
        return [frontier, new_line];
      } else {
        let check = numeral_stack.pop();
        // Otherwise, go from top of frontier down to find first prior match
        // Frontier becomes (stack-pop)+latest
        let exact_expected = check_for_match(frontier, check, (f, c) => f + 1 === c);
        if (exact_expected) {
          frontier = exact_expected;
          let last = frontier[frontier.length - 1];
          last[_.keys(last)[0]] += 1;
          new_line.depth = to_depth(frontier);
          return [frontier, new_line];
        }
        // No matching type+level in frontier!
        // Just look for an increase then.
        let approx_expected = check_for_match(frontier, check, (f, c) => f < c);
        if (approx_expected) {
          frontier = approx_expected;
          let last = frontier[frontier.length - 1];
          let last_key = _.keys(last)[0];
          last[last_key] = check[last_key];
          new_line.depth = to_depth(frontier);
          return [frontier, new_line];
        }

        let o = smallest_numeral(check);
        frontier.push(o);
        new_line.depth = to_depth(frontier);
        return [frontier, new_line];
      }
    }
    // Enum stack has more than one item
    // Assume the line is fully enumed up front,
    // make sure enum types align
    frontier = numeral_stack.map((el, ind) => {
      if (ind < frontier.length) {
        return _.pick(el, _.keys(frontier[ind]));
      }
      return smallest_numeral(el);
    });
    new_line.depth = to_depth(frontier);
    return [frontier, new_line];
  }

  let guess;
  for (let line of lines) {
    let gal = guess_a_line(frontier, line);
    frontier = gal[0];
    guess = gal[1];
    guessed_lines.push(guess);
  }
  return guessed_lines;
}

const caseLike = /(\bvs?\b)|(\bin re:\b)|(ex parte)/i;
const removeParenthetical = /\([^)]*\)/;
const guessCitation = /[0-9]+\s+[a-zA-Z0-9 .]*\b\s*[0-9]+/;
const caseLawLink = /https?:\/\/cite\.case\.law\/[/0-9a-zA-Z_-]*/;
function looksLikeCaseName(str) {
  return !!(str.match(caseLike) || str.match(guessCitation) || str.match(caseLawLink));
}

const linkLike = /https?:\/\/(?:[\w]+\.)(?:\.?[\w]{2,})/;
function looksLikeLink(str) {
  return !!(str.match(linkLike));
}

function extractLink(str) {
  const grabLink = str.match(linkLike);
  if (grabLink && grabLink.length === 1) {
    return grabLink[0];
  }
  return str;
}

function extractCaseSearch(string) {
  const ungarnished = string.replace(removeParenthetical, '');
  let citeGuesses = ungarnished.match(guessCitation);
  let caseLawGuesses = ungarnished.match(caseLawLink);
  if (caseLawGuesses && caseLawGuesses.length === 1) {
    return caseLawGuesses[0];
  }
  if (citeGuesses && citeGuesses.length === 1) {
    return citeGuesses[0];
  }
  return ungarnished.trim();
}

function looksLikeSelfLink(line) {
  const origin = window.location.origin;
  return line.indexOf(origin) >= 0;
}

function findSelfLinkMatch(line) {
  const urlFns = _.keys(FRONTEND_URLS).map(urlName => (
    {
      name: urlName,
      match: urls.matcher(urlName),
      reverser: urls.reverser(urlName)
    }));
  let cands = urlFns.filter(u => u.match.exec(line)).map(u => u.reverser(line));
  if (cands.length > 1) {
    console.log(cands);
  }
  return cands.length > 0 && cands[0];
}


function guessLineType(line) {
  if (looksLikeCaseName(line)) {
    return {resource_type: 'Case', searchString: extractCaseSearch(line)};
  } else if (looksLikeSelfLink(line)) {
    let params = findSelfLinkMatch(line);
    if (_.has(params, 'caseId')) {
      return {resource_type: 'Case', resource_id: params.caseId};
    } else if (_.has(params, 'casebookId')) {
      return {resource_type: 'Clone', casebookId: params.casebookId, sectionId: params.sectionId || params.resourceId, sectionOrd: params.sectionOrd || params.resourceOrd};
    }
    return {resource_type: 'Link', url: extractLink(line)};
  } else if (looksLikeLink(line)) {
    return {resource_type: 'Link', url: extractLink(line)};
  } else {
    return {resource_type: 'Unknown', title: line};
  }
}

function cleanDocLines(text) {
  // This is a group of heuristics that I think are reasonable based on a smattering of
  // Tables of contents and syllabi that I pulled from online sources.
  // It works by parsing one line at a time

  let lines = text.split("\n").map(x => x.trim()).filter(x => x.length > 0);
  let merged_lines = merge_wrapped_lines(lines);
  let enumerated_lines = merged_lines.map(enumeration_identification);
  let deep_lines = guess_line_depth(enumerated_lines);
  return deep_lines;
}

function structureOutline(lines) {

  function getPath(node, path) {
    if (path.length === 0 || !node) {
      return node;
    }
    const key = path[0];
    const rest = path.slice(1);
    if (key >= node.children.length) {
      return null;
    }
    return getPath(node.children[key], rest);
  }
  let root = {
    title: "Root",
    type: "root",
    children: []
  };
  let stats = {};
  let path = [];
  for (let ii = 0; ii < lines.length; ii++) {
    let previous_depth = (ii > 0 && lines[ii - 1].depth) || 1;
    let next_depth = (ii + 1 < lines.length && lines[ii + 1].depth) || 1;
    let { depth, title } = lines[ii];

    while (previous_depth > depth) {
      path.pop();
      previous_depth--;
    }

    let currentNode = { title, resource_type: 'Temp', children: [] };
    let lineGuess = guessLineType(title);
    let hasChildren = next_depth > depth;
    if (hasChildren) {
      currentNode.resource_type = 'Section';
    } else {
      _.merge(currentNode,lineGuess);
    }
    stats[currentNode.resource_type] = _.get(stats, currentNode.resource_type, 0) + 1;
    let parent = getPath(root, path);
    if (hasChildren) {
      path.push(parent.children.length);
    }
    parent.children.push(currentNode);

  }
  return [root,stats];
}


export default {
  cleanDocLines,
  structureOutline,
  guessLineType,
  extractCaseSearch
};

