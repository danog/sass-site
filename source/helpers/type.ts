import { LoremIpsum } from 'lorem-ipsum';
import { typogrify } from 'typogr';

import { markdownEngine } from './engines';

const lorem = new LoremIpsum();

/**
 * Returns block of generated `lorem ipsum` text.
 *
 * @see https://github.com/knicklabs/lorem-ipsum.js
 */
export const getLorem = (type: string, number = 1) => {
  switch (type) {
    case 'sentence':
    case 'sentences':
      return lorem.generateSentences(number);
    case 'paragraph':
    case 'paragraphs':
      return lorem.generateParagraphs(number);
    case 'word':
    case 'words':
      return lorem.generateWords(number);
  }
  return '';
};

/**
 * Renders block of Markdown into HTML.
 */
export const markdown = (content: string) => markdownEngine.render(content);

/**
 * Renders single line of Markdown into HTML, without wrapping `<p>`.
 */
export const markdownInline = (content: string) =>
  markdownEngine.renderInline(content);

/**
 * Applies various transformations to plain text in order to yield
 * typographically-improved HTML.
 *
 * @see https://github.com/ekalinin/typogr.js
 */
export const typogr = (content: string) => typogrify(content);

/* eslint-disable @typescript-eslint/no-unsafe-member-access,
                  @typescript-eslint/no-unsafe-call,
                  @typescript-eslint/no-explicit-any */
export default function typePlugin(eleventyConfig: any) {
  // filters...
  eleventyConfig.addLiquidFilter('markdown', markdown);
  eleventyConfig.addLiquidFilter('markdownInline', markdownInline);
  eleventyConfig.addLiquidFilter('typogr', typogr);

  // shortcodes...
  eleventyConfig.addLiquidShortcode('lorem', getLorem);

  // paired shortcodes...
  eleventyConfig.addPairedLiquidShortcode('markdown', markdown);
  eleventyConfig.addPairedLiquidShortcode('markdownInline', markdownInline);
  eleventyConfig.addPairedLiquidShortcode('typogr', typogr);
}
