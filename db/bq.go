package db

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/bigquery"
	"google.golang.org/api/iterator"
)

const (
	project = "icco-cloud"
)

type Entry struct {
	Size     Size
	Image    string
	Title    string
	Modified time.Time
	URL      string
}

type Size struct {
	Height int64
	Width  int64
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

	for {
		var c countResponse
		err := it.Next(&c)
		if err == iterator.Done {
			break
		}
		if err != nil {
			return 0, err
		}

		return c.Cnt, nil
	}

	return 0, fmt.Errorf("got to impossible state")
}

func Page(ctx context.Context, n int64) ([]*Entry, error) {
	client, err := bigquery.NewClient(ctx, project)
	if err != nil {
		return nil, err
	}

	query := client.Query("SELECT * FROM `icco-cloud.inspiration.cache` WHERE url is not null ORDER BY rand() * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) LIMIT @per_page OFFSET @offset")
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
