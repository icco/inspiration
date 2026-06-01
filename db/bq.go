// Package db provides BigQuery-backed access to cached inspiration entries.
package db

import (
	"context"
	"errors"
	"fmt"

	"cloud.google.com/go/bigquery"
	"google.golang.org/api/iterator"
)

const (
	project = "icco-cloud"
)

// Entry is a single cached image record from the inspiration BigQuery table.
type Entry struct {
	Size     Size                   `bigquery:"size" json:"size"`
	Image    bigquery.NullString    `bigquery:"image" json:"image"`
	Title    bigquery.NullString    `bigquery:"title" json:"title"`
	Modified bigquery.NullTimestamp `bigquery:"modified" json:"modified"`
	URL      bigquery.NullString    `bigquery:"url" json:"url"`
}

// Size holds the pixel dimensions of an Entry's image.
type Size struct {
	Height bigquery.NullInt64 `bigquery:"height" json:"height"`
	Width  bigquery.NullInt64 `bigquery:"width" json:"width"`
}

type countResponse struct {
	Cnt int64
}

// Count returns the total number of rows in the inspiration cache table.
func Count(ctx context.Context) (int64, error) {
	client, err := bigquery.NewClient(ctx, project)
	if err != nil {
		return 0, err
	}

	query := client.Query("SELECT count(*) as cnt FROM `icco-cloud.inspiration.cache`")
	it, err := query.Read(ctx)
	if err != nil {
		return 0, err
	}

	var c countResponse
	if err = it.Next(&c); err != nil {
		if errors.Is(err, iterator.Done) {
			return 0, fmt.Errorf("could not get count")
		}

		return 0, err
	}

	return c.Cnt, nil
}

// Page returns up to perPage entries from page n (1-indexed) of the cache,
// shuffled by a per-day seed so callers get a stable order within a day.
func Page(ctx context.Context, n, perPage int64) ([]*Entry, error) {
	client, err := bigquery.NewClient(ctx, project)
	if err != nil {
		return nil, err
	}

	query := client.Query("SELECT * FROM `icco-cloud.inspiration.cache` WHERE url is not null ORDER BY rand() * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) LIMIT @per_page OFFSET @offset")
	query.Parameters = []bigquery.QueryParameter{
		{Name: "per_page", Value: perPage},
		{Name: "offset", Value: (n - 1) * perPage},
	}

	it, err := query.Read(ctx)
	if err != nil {
		return nil, err
	}

	var entries []*Entry
	for {
		var e Entry
		err := it.Next(&e)
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, err
		}

		entries = append(entries, &e)
	}

	return entries, nil
}

// Get returns the cache entries whose URL matches any value in urls.
func Get(ctx context.Context, urls []string) ([]*Entry, error) {
	client, err := bigquery.NewClient(ctx, project)
	if err != nil {
		return nil, err
	}

	query := client.Query("SELECT * FROM `icco-cloud.inspiration.cache` WHERE url IN UNNEST(@urls)")
	query.Parameters = []bigquery.QueryParameter{
		{Name: "urls", Value: urls},
	}

	it, err := query.Read(ctx)
	if err != nil {
		return nil, err
	}

	var entries []*Entry
	for {
		var e Entry
		err := it.Next(&e)
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, err
		}

		entries = append(entries, &e)
	}

	return entries, nil
}
