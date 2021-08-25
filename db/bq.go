package db

import (
	"context"
	"fmt"

	"cloud.google.com/go/bigquery"
	"google.golang.org/api/iterator"
)

const (
	project = "icco-cloud"
)

type Entry struct {
	Size     Size                   `bigquery:"size" json:"size"`
	Image    bigquery.NullString    `bigquery:"image" json:"image"`
	Title    bigquery.NullString    `bigquery:"title" json:"title"`
	Modified bigquery.NullTimestamp `bigquery:"modified" json:"modified"`
	URL      bigquery.NullString    `bigquery:"url" json:"url"`
}

type Size struct {
	Height bigquery.NullInt64 `bigquery:"height" json:"height"`
	Width  bigquery.NullInt64 `bigquery:"width" json:"width"`
}

type countResponse struct {
	Cnt int64
}

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
		if err == iterator.Done {
			return 0, fmt.Errorf("could not get count")
		}

		return 0, err
	}

	return c.Cnt, nil
}

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
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		entries = append(entries, &e)
	}

	return entries, nil
}

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
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		entries = append(entries, &e)
	}

	return entries, nil
}
